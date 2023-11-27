// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { IAutomationCompatible } from "../../interfaces/IAutomationCompatible.sol";
import { IFeeManager, FeeAsset } from "../../interfaces/IFeeManager.sol";
import { ILogAutomation, Log as AutomationLog } from "../../interfaces/ILogAutomation.sol";
import { IStreamsLookupCompatible, BasicReport } from "../../interfaces/IStreamsLookupCompatible.sol";
import { IVerifierProxy } from "../../interfaces/IVerifierProxy.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { PerpsEngine } from "@zaros/markets/perps/PerpsEngine.sol";
import { SettlementStrategy } from "@zaros/markets/perps/storage/SettlementStrategy.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract LimitOrderUpkeep is IAutomationCompatible, IStreamsLookupCompatible, UUPSUpgradeable, OwnableUpgradeable {
    using EnumerableSet for EnumerableSet.UintSet;

    /// @notice ERC7201 storage location.
    bytes32 internal constant LIMIT_ORDER_UPKEEP_LOCATION = keccak256(
        abi.encode(uint256(keccak256("fi.zaros.external.chainlink.upkeeps.LimitOrderUpkeep")) - 1)
    ) & ~bytes32(uint256(0xff));

    /// @custom:storage-location erc7201:fi.zaros.external.chainlink.LimitOrderUpkeep
    /// @param chainlinkVerifier The address of the Chainlink Verifier contract.
    /// @param forwarder The address of the Upkeep forwarder contract.
    /// @param perpsEngine The address of the PerpsEngine contract.
    struct LimitOrderUpkeepStorage {
        address chainlinkVerifier;
        address forwarder;
        PerpsEngine perpsEngine;
        EnumerableSet.UintSet accountsWithActiveOrders;
        EnumerableSet.UintSet supportedMarketsIds;
        uint256 nextOrderId;
        mapping(uint128 marketId => mapping(uint128 accountId => EnumerableSet.UintSet))
            limitOrdersIdsPerAccountPerMarket;
    }

    /// @notice {LimitOrderUpkeep} UUPS initializer.
    function initialize(
        address initialOwner,
        address chainlinkVerifier,
        address forwarder,
        PerpsEngine perpsEngine
    )
        external
        initializer
    {
        if (chainlinkVerifier == address(0)) {
            revert Errors.ZeroInput("chainlinkVerifier");
        }
        if (forwarder == address(0)) {
            revert Errors.ZeroInput("forwarder");
        }
        if (address(perpsEngine) == address(0)) {
            revert Errors.ZeroInput("perpsEngine");
        }

        LimitOrderUpkeepStorage storage self = _getLimitOrderUpkeepStorage();

        self.chainlinkVerifier = chainlinkVerifier;
        self.forwarder = forwarder;
        self.perpsEngine = perpsEngine;

        __Ownable_init(initialOwner);
    }

    function checkUpkeep(bytes calldata checkData)
        external
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        this;
    }

    function checkCallback(
        bytes[] calldata values,
        bytes calldata extraData
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        this;
    }

    function createLimitOrder(uint128 accountId, uint128 marketId, uint128 price, uint128 sizeDelta) external {
        LimitOrderUpkeepStorage storage self = _getLimitOrderUpkeepStorage();

        if (!self.supportedMarketIds.contains(marketId)) {
            revert Errors.UnsupportedMarketId(marketId);
        }

        if (!self.accountsWithActiveOrders.contains(accountId)) {
            self.accountsWithActiveOrders.add(accountId);
        }
        uint128 orderId = ++self.nextOrderId;

        if (!self.limitOrdersIdsPerAccountPerMarket[marketId][accountId].contains(orderId)) {
            self.limitOrdersIdsPerAccountPerMarket[marketId][accountId].add(orderId);
        }

        LimitOrder.create({
            accountId: accountId,
            marketId: marketId,
            orderId: orderId,
            price: price,
            sizeDelta: sizeDelta
        });

        emit LogCreateLimitOrder(marketId, accountId, orderId, price, sizeDelta);
    }

    function performUpkeep(bytes calldata performData) external override {
        this;
    }

    function _getLimitOrderUpkeepStorage() internal pure returns (LimitOrderUpkeepStorage storage self) {
        bytes32 slot = LIMIT_ORDER_UPKEEP_LOCATION;

        assembly {
            self.slot := slot
        }
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address) internal override onlyOwner { }
}
