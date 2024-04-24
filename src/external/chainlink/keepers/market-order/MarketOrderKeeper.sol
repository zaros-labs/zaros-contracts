// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { IPerpsEngine } from "@zaros/perpetuals/interfaces/IPerpsEngine.sol";
import { ILogAutomation, Log as AutomationLog } from "../../interfaces/ILogAutomation.sol";
import { IStreamsLookupCompatible } from "../../interfaces/IStreamsLookupCompatible.sol";
import { BaseKeeper } from "../BaseKeeper.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { MarketOrder } from "@zaros/perpetuals/leaves/MarketOrder.sol";

// Open Zeppelin dependencies
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

contract MarketOrderKeeper is ILogAutomation, IStreamsLookupCompatible, BaseKeeper {
    using SafeCast for uint256;

    /// @notice ERC7201 storage location.
    bytes32 internal constant MARKET_ORDER_KEEPER_LOCATION = keccak256(
        abi.encode(uint256(keccak256("fi.zaros.external.chainlink.keepers.MarketOrderKeeper")) - 1)
    ) & ~bytes32(uint256(0xff));

    /// @notice index of the account id param at LogCreateMarketOrder.
    uint256 internal constant LOG_CREATE_MARKET_ORDER_ACCOUNT_ID_INDEX = 2;

    /// @custom:storage-location erc7201:fi.zaros.external.chainlink.MarketOrderKeeper
    /// @param perpsEngine The address of the PerpsEngine contract.
    /// @param feeReceiver The address that receives settlement fees.
    /// @param marketId The perps market id that the keeper should fill market orders for.
    /// @param streamId The Chainlink Data Streams stream id.
    struct MarketOrderKeeperStorage {
        IPerpsEngine perpsEngine;
        address feeReceiver;
        uint128 marketId;
        string streamId;
        string feedLabel;
        string queryLabel;
    }

    constructor() {
        _disableInitializers();
    }

    /// @notice {MarketOrderKeeper} UUPS initializer.
    /// @param owner The address of the owner of the keeper.
    /// @param perpsEngine The address of the PerpsEngine contract.
    /// @param feeReceiver The address that receives settlement fees.
    /// @param marketId The perps market id that the keeper should fill market orders for.
    function initialize(
        address owner,
        IPerpsEngine perpsEngine,
        address feeReceiver,
        uint128 marketId,
        string calldata streamId
    )
        external
        initializer
    {
        __BaseKeeper_init(owner);

        if (address(perpsEngine) == address(0)) {
            revert Errors.ZeroInput("perpsEngine");
        }
        if (feeReceiver == address(0)) {
            revert Errors.ZeroInput("feeReceiver");
        }
        if (marketId == 0) {
            revert Errors.ZeroInput("marketId");
        }
        if (bytes(streamId).length == 0) {
            revert Errors.ZeroInput("streamId");
        }

        MarketOrderKeeperStorage storage self = _getMarketOrderKeeperStorage();

        self.perpsEngine = perpsEngine;
        self.feeReceiver = feeReceiver;
        self.marketId = marketId;
        self.streamId = streamId;
    }

    function getConfig()
        public
        view
        returns (address keeperOwner, address forwarder, address perpsEngine, address feeReceiver, uint128 marketId)
    {
        BaseKeeperStorage storage baseKeeperStorage = _getBaseKeeperStorage();
        MarketOrderKeeperStorage storage self = _getMarketOrderKeeperStorage();

        keeperOwner = owner();
        forwarder = baseKeeperStorage.forwarder;
        perpsEngine = address(self.perpsEngine);
        feeReceiver = self.feeReceiver;
        marketId = self.marketId;
    }

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
        uint128 accountId = uint256(log.topics[LOG_CREATE_MARKET_ORDER_ACCOUNT_ID_INDEX]).toUint128();
        (MarketOrder.Data memory marketOrder) = abi.decode(log.data, (MarketOrder.Data));

        MarketOrderKeeperStorage storage self = _getMarketOrderKeeperStorage();

        string[] memory streams = new string[](1);
        streams[0] = self.streamId;
        uint256 settlementTimestamp = marketOrder.timestamp;
        bytes memory extraData = abi.encode(accountId);

        revert StreamsLookup(self.feedLabel, streams, self.queryLabel, settlementTimestamp, extraData);
    }

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

    /// @notice Updates the market order keeper configuration.
    /// @param perpsEngine The address of the PerpsEngine contract.
    /// @param feeReceiver The address that receives settlement fees.
    /// @param marketId The perps market id that the keeper should fill market orders for.
    function updateConfig(
        IPerpsEngine perpsEngine,
        address feeReceiver,
        uint128 marketId,
        string calldata streamId
    )
        external
        onlyOwner
    {
        if (address(perpsEngine) == address(0)) {
            revert Errors.ZeroInput("perpsEngine");
        }
        if (feeReceiver == address(0)) {
            revert Errors.ZeroInput("feeReceiver");
        }
        if (marketId == 0) {
            revert Errors.ZeroInput("marketId");
        }
        if (bytes(streamId).length == 0) {
            revert Errors.ZeroInput("streamId");
        }

        MarketOrderKeeperStorage storage self = _getMarketOrderKeeperStorage();
        self.perpsEngine = perpsEngine;
        self.feeReceiver = feeReceiver;
        self.marketId = marketId;
        self.streamId = streamId;
    }

    /// @inheritdoc ILogAutomation
    function performUpkeep(bytes calldata performData) external onlyForwarder {
        (bytes memory signedReport, bytes memory extraData) = abi.decode(performData, (bytes, bytes));
        uint128 accountId = abi.decode(extraData, (uint128));

        MarketOrderKeeperStorage storage self = _getMarketOrderKeeperStorage();
        (IPerpsEngine perpsEngine, address feeReceiver, uint128 marketId) =
            (self.perpsEngine, self.feeReceiver, self.marketId);

        perpsEngine.fillMarketOrder(accountId, marketId, feeReceiver, signedReport);
    }

    function _getMarketOrderKeeperStorage() internal pure returns (MarketOrderKeeperStorage storage self) {
        bytes32 slot = MARKET_ORDER_KEEPER_LOCATION;

        assembly {
            self.slot := slot
        }
    }
}
