// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { IFeeManager, FeeAsset } from "../../interfaces/IFeeManager.sol";
import { ILogAutomation, Log as AutomationLog } from "../../interfaces/ILogAutomation.sol";
import { IStreamsLookupCompatible } from "../../interfaces/IStreamsLookupCompatible.sol";
import { IVerifierProxy } from "../../interfaces/IVerifierProxy.sol";
import { BaseUpkeep } from "../BaseUpkeep.sol";
import { ChainlinkUtil } from "../../ChainlinkUtil.sol";
import { Constants } from "@zaros/utils/Constants.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { PerpsEngine } from "@zaros/markets/perps/PerpsEngine.sol";
import { ISettlementModule } from "@zaros/markets/perps/interfaces/ISettlementModule.sol";
import { Order } from "@zaros/markets/perps/storage/Order.sol";
import { SettlementConfiguration } from "@zaros/markets/perps/storage/SettlementConfiguration.sol";

// Open Zeppelin dependencies
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

contract MarketOrderUpkeep is ILogAutomation, IStreamsLookupCompatible, BaseUpkeep {
    using SafeCast for uint256;

    /// @notice ERC7201 storage location.
    bytes32 internal constant MARKET_ORDER_UPKEEP_LOCATION = keccak256(
        abi.encode(uint256(keccak256("fi.zaros.external.chainlink.upkeeps.MarketOrderUpkeep")) - 1)
    ) & ~bytes32(uint256(0xff));

    /// @custom:storage-location erc7201:fi.zaros.external.chainlink.MarketOrderUpkeep
    /// @param settlementStrategy The market order settlement strategy contract.
    struct MarketOrderUpkeepStorage {
        PerpsEngine perpsEngine;
    }

    /// @notice {MarketOrderUpkeep} UUPS initializer.
    function initialize(address forwarder, PerpsEngine perpsEngine) external initializer {
        __BaseUpkeep_init(forwarder);

        if (address(perpsEngine) == address(0)) {
            revert Errors.ZeroInput("settlementStrategy");
        }

        MarketOrderUpkeepStorage storage self = _getMarketOrderUpkeepStorage();

        self.perpsEngine = perpsEngine;
    }

    function getConfig() public view returns (address upkeepOwner, address forwarder, address perpsEngine) {
        BaseUpkeepStorage storage baseUpkeepStorage = _getBaseUpkeepStorage();
        MarketOrderUpkeepStorage storage self = _getMarketOrderUpkeepStorage();

        upkeepOwner = owner();
        forwarder = baseUpkeepStorage.forwarder;
        perpsEngine = address(self.perpsEngine);
    }

    /// TODO: add check if upkeep is turned on (check contract's ETH funding)
    /// @inheritdoc ILogAutomation
    function checkLog(
        AutomationLog calldata log,
        bytes calldata checkData
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        MarketOrderUpkeepStorage storage self = _getMarketOrderUpkeepStorage();
        PerpsEngine perpsEngine = self.perpsEngine;

        (uint128 accountId, uint128 marketId) = (uint256(log.topics[2]).toUint128(), uint256(log.topics[3]).toUint128());
        (Order.Market memory marketOrder) = abi.decode(log.data, (Order.Market));

        SettlementConfiguration.Data memory settlementConfiguration =
            perpsEngine.getSettlementConfiguration(marketId, SettlementConfiguration.MARKET_ORDER_SETTLEMENT_ID);
        SettlementConfiguration.DataStreamsMarketStrategy memory marketOrderStrategy =
            abi.decode(settlementConfiguration.data, (SettlementConfiguration.DataStreamsMarketStrategy));

        string[] memory streams = new string[](1);
        streams[0] = string(abi.encodePacked(marketOrderStrategy.streamId));
        uint256 settlementTimestamp = marketOrder.timestamp + marketOrderStrategy.settlementDelay;
        bytes memory extraData = abi.encode(accountId, marketId);

        revert StreamsLookup(
            marketOrderStrategy.feedLabel, streams, marketOrderStrategy.queryLabel, settlementTimestamp, extraData
        );
    }

    /// TODO: compare gas optimization pre-loading variables here vs in performUpkeep. Remember of Arbitrum's l1 gas
    /// cost (calldata is the most expensive place).
    /// @inheritdoc IStreamsLookupCompatible
    function checkCallback(
        bytes[] calldata values,
        bytes calldata extraData
    )
        external
        pure
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        bytes memory signedReport = values[0];

        upkeepNeeded = true;
        performData = abi.encode(signedReport, extraData);
    }

    /// @inheritdoc ILogAutomation
    function performUpkeep(bytes calldata performData) external onlyForwarder {
        (bytes memory signedReport, uint128 accountId, uint128 marketId) =
            abi.decode(performData, (bytes, uint128, uint128));

        MarketOrderUpkeepStorage storage self = _getMarketOrderUpkeepStorage();
        (PerpsEngine perpsEngine) = (self.perpsEngine);

        perpsEngine.settleMarketOrder(accountId, marketId, signedReport);
    }

    function _getMarketOrderUpkeepStorage() internal pure returns (MarketOrderUpkeepStorage storage self) {
        bytes32 slot = MARKET_ORDER_UPKEEP_LOCATION;

        assembly {
            self.slot := slot
        }
    }
}
