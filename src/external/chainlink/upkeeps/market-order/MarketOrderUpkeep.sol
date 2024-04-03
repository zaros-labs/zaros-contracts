// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { IPerpsEngine } from "@zaros/markets/perps/interfaces/IPerpsEngine.sol";
import { ILogAutomation, Log as AutomationLog } from "../../interfaces/ILogAutomation.sol";
import { IStreamsLookupCompatible } from "../../interfaces/IStreamsLookupCompatible.sol";
import { BaseUpkeep } from "../BaseUpkeep.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { MarketOrder } from "@zaros/markets/perps/storage/MarketOrder.sol";
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
    /// @param perpsEngine The address of the PerpsEngine contract.
    /// @param feeReceiver The address that receives settlement fees.
    /// @param marketId The perps market id that the keeper should execute market orders for.
    struct MarketOrderUpkeepStorage {
        IPerpsEngine perpsEngine;
        address feeReceiver;
        uint128 marketId;
    }

    constructor() {
        _disableInitializers();
    }

    /// @notice {MarketOrderUpkeep} UUPS initializer.
    /// @param owner The address of the owner of the keeper.
    /// @param perpsEngine The address of the PerpsEngine contract.
    /// @param feeReceiver The address that receives settlement fees.
    /// @param marketId The perps market id that the keeper should execute market orders for.
    function initialize(
        address owner,
        IPerpsEngine perpsEngine,
        address feeReceiver,
        uint128 marketId
    )
        external
        initializer
    {
        __BaseUpkeep_init(owner);

        if (address(perpsEngine) == address(0)) {
            revert Errors.ZeroInput("perpsEngine");
        }
        if (feeReceiver == address(0)) {
            revert Errors.ZeroInput("feeReceiver");
        }
        if (marketId == 0) {
            revert Errors.ZeroInput("marketId");
        }

        MarketOrderUpkeepStorage storage self = _getMarketOrderUpkeepStorage();

        self.perpsEngine = perpsEngine;
        self.feeReceiver = feeReceiver;
        self.marketId = marketId;
    }

    function getConfig()
        public
        view
        returns (address upkeepOwner, address forwarder, address perpsEngine, address feeReceiver, uint128 marketId)
    {
        BaseUpkeepStorage storage baseUpkeepStorage = _getBaseUpkeepStorage();
        MarketOrderUpkeepStorage storage self = _getMarketOrderUpkeepStorage();

        upkeepOwner = owner();
        forwarder = baseUpkeepStorage.forwarder;
        perpsEngine = address(self.perpsEngine);
        feeReceiver = self.feeReceiver;
        marketId = self.marketId;
    }

    /// TODO: add check if upkeep is turned on (check contract's ETH funding)
    /// @inheritdoc ILogAutomation
    function checkLog(
        AutomationLog calldata log,
        bytes calldata
    )
        external
        view
        override
        returns (bool, bytes memory)
    {
        MarketOrderUpkeepStorage storage self = _getMarketOrderUpkeepStorage();
        MarketOrderSettlementStrategy settlementStrategy = self.settlementStrategy;

        uint128 accountId = uint256(log.topics[2]).toUint128();
        (MarketOrder.Data memory marketOrder) = abi.decode(log.data, (MarketOrder.Data));

        SettlementConfiguration.Data memory settlementConfiguration =
            settlementStrategy.getZarosSettlementConfiguration();
        SettlementConfiguration.DataStreamsMarketStrategy memory marketOrderConfiguration =
            abi.decode(settlementConfiguration.data, (SettlementConfiguration.DataStreamsMarketStrategy));

        string[] memory streams = new string[](1);
        streams[0] = marketOrderConfiguration.streamId;
        uint256 settlementTimestamp = marketOrder.timestamp + marketOrderConfiguration.settlementDelay;
        bytes memory extraData = abi.encode(accountId);

        revert StreamsLookup(
            marketOrderConfiguration.feedLabel,
            streams,
            marketOrderConfiguration.queryLabel,
            settlementTimestamp,
            extraData
        );
    }

    /// TODO: compare gas optimization pre-loading variables here vs in performUpkeep. Remember of Arbitrum's l1
    /// gas
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

    /// @notice Updates the address that receives settlement fees.
    /// @param newFeeReceiver The new address that receives settlement fees.
    function updateFeeReceiver(address newFeeReceiver) external onlyOwner {
        if (newFeeReceiver == address(0)) {
            revert Errors.ZeroInput("newFeeReceiver");
        }

        MarketOrderUpkeepStorage storage self = _getMarketOrderUpkeepStorage();
        self.feeReceiver = newFeeReceiver;
    }

    /// @inheritdoc ILogAutomation
    function performUpkeep(bytes calldata performData) external onlyForwarder {
        (bytes memory signedReport, bytes memory extraData) = abi.decode(performData, (bytes, bytes));
        uint128 accountId = abi.decode(extraData, (uint128));

        MarketOrderUpkeepStorage storage self = _getMarketOrderUpkeepStorage();
        (IPerpsEngine perpsEngine, address feeReceiver, uint128 marketId) =
            (self.perpsEngine, self.feeReceiver, self.marketId);

        // TODO: Update the fee receiver to an address managed / stored by the keeper.
        perpsEngine.executeMarketOrder(accountId, marketId, feeReceiver, signedReport);
    }

    function _getMarketOrderUpkeepStorage() internal pure returns (MarketOrderUpkeepStorage storage self) {
        bytes32 slot = MARKET_ORDER_UPKEEP_LOCATION;

        assembly {
            self.slot := slot
        }
    }
}
