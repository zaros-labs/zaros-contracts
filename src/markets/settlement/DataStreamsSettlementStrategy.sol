// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { IPerpsEngine } from "@zaros/markets/perps/interfaces/IPerpsEngine.sol";
import { ISettlementModule } from "@zaros/markets/perps/interfaces/ISettlementModule.sol";
import { SettlementConfiguration } from "@zaros/markets/perps/storage/SettlementConfiguration.sol";
import { ISettlementStrategy } from "./interfaces/ISettlementStrategy.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";

abstract contract DataStreamsSettlementStrategy is ISettlementStrategy, OwnableUpgradeable, UUPSUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice Chainlink Data Streams Reports default decimals (both Basic and Premium).
    uint8 internal constant REPORT_PRICE_DECIMALS = 8;

    /// @notice ERC7201 storage location.
    bytes32 internal constant DATA_STREAMS_SETTLEMENT_STRATEGY_LOCATION = keccak256(
        abi.encode(uint256(keccak256("fi.zaros.markets.settlement.DataStreamsSettlementStrategy")) - 1)
    ) & ~bytes32(uint256(0xff));

    /// @custom:storage-location erc7201:fi.zaros.external.chainlink.DataStreamsSettlementStrategy
    /// @param perpsEngine The address of the PerpsEngine contract.
    /// @param keepers The set of registered keepers addresses.
    /// @param marketId The Zaros perp market id which is using this strategy.
    /// @param settlementId The Zaros perp market settlement strategy id linked to this contract.
    struct DataStreamsSettlementStrategyStorage {
        IPerpsEngine perpsEngine;
        EnumerableSet.AddressSet keepers;
        uint128 marketId;
        uint128 settlementId;
    }

    /// @notice Ensures that only a registered keeper is able to call a function.
    modifier onlyRegisteredKeeper() {
        DataStreamsSettlementStrategyStorage storage self = _getDataStreamsSettlementStrategyStorage();
        bool isValidSender = self.keepers.contains(msg.sender);

        if (!isValidSender) {
            revert Errors.Unauthorized(msg.sender);
        }
        _;
    }

    modifier onlyPerpsEngine() {
        DataStreamsSettlementStrategyStorage storage self = _getDataStreamsSettlementStrategyStorage();
        bool isSenderPerpsEngine = msg.sender == address(self.perpsEngine);

        if (!isSenderPerpsEngine) {
            revert Errors.Unauthorized(msg.sender);
        }
        _;
    }

    function getConfig()
        public
        view
        virtual
        returns (
            address settlementStrategyOwner,
            address[] memory keepers,
            address perpsEngine,
            uint128 marketId,
            uint128 settlementId
        )
    {
        DataStreamsSettlementStrategyStorage storage self = _getDataStreamsSettlementStrategyStorage();

        settlementStrategyOwner = owner();
        keepers = _getKeepers();
        perpsEngine = address(self.perpsEngine);
        marketId = self.marketId;
        settlementId = self.settlementId;
    }

    function getZarosSettlementConfiguration() external view returns (SettlementConfiguration.Data memory) {
        DataStreamsSettlementStrategyStorage storage dataStreamsCustomSettlementStrategyStorage =
            _getDataStreamsSettlementStrategyStorage();

        IPerpsEngine perpsEngine = dataStreamsCustomSettlementStrategyStorage.perpsEngine;
        uint128 marketId = dataStreamsCustomSettlementStrategyStorage.marketId;
        uint128 settlementId = dataStreamsCustomSettlementStrategyStorage.settlementId;

        SettlementConfiguration.Data memory settlementConfiguration =
            perpsEngine.getSettlementConfiguration(marketId, settlementId);

        return settlementConfiguration;
    }

    function setKeepers(address[] calldata keepers) external onlyOwner {
        if (keepers.length == 0) {
            revert Errors.ZeroInput("keepers");
        }

        DataStreamsSettlementStrategyStorage storage self = _getDataStreamsSettlementStrategyStorage();

        for (uint256 i = 0; i < keepers.length; i++) {
            self.keepers.add(keepers[i]);
        }
    }

    function removeKeepers(address[] calldata keepers) external onlyOwner {
        if (keepers.length == 0) {
            revert Errors.ZeroInput("keepers");
        }

        DataStreamsSettlementStrategyStorage storage self = _getDataStreamsSettlementStrategyStorage();

        for (uint256 i = 0; i < keepers.length; i++) {
            self.keepers.remove(keepers[i]);
        }
    }

    function settle(bytes calldata signedReport, bytes calldata extraData) external virtual;

    /// @notice {DataStreamsSettlementStrategy} UUPS initializer.
    function __DataStreamsSettlementStrategy_init(
        IPerpsEngine perpsEngine,
        uint128 marketId,
        uint128 settlementId
    )
        internal
        onlyInitializing
    {
        __Ownable_init(msg.sender);

        if (address(perpsEngine) == address(0)) {
            revert Errors.ZeroInput("perpsEngine");
        }
        if (marketId == 0) {
            revert Errors.ZeroInput("marketId");
        }

        DataStreamsSettlementStrategyStorage storage self = _getDataStreamsSettlementStrategyStorage();

        self.perpsEngine = perpsEngine;
        self.marketId = marketId;
        self.settlementId = settlementId;
    }

    function _getKeepers() internal view returns (address[] memory keepers) {
        DataStreamsSettlementStrategyStorage storage self = _getDataStreamsSettlementStrategyStorage();

        keepers = new address[](self.keepers.length());

        for (uint256 i = 0; i < self.keepers.length(); i++) {
            keepers[i] = self.keepers.at(i);
        }
    }

    function _getDataStreamsSettlementStrategyStorage()
        internal
        pure
        returns (DataStreamsSettlementStrategyStorage storage self)
    {
        bytes32 slot = DATA_STREAMS_SETTLEMENT_STRATEGY_LOCATION;

        assembly {
            self.slot := slot
        }
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address) internal override onlyOwner { }
}
