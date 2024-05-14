// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { IAutomationCompatible } from "@zaros/external/chainlink/interfaces/IAutomationCompatible.sol";
import { IPerpsEngine } from "@zaros/perpetuals/PerpsEngine.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { BaseKeeper } from "../BaseKeeper.sol";

// TODO: store margin and liquidation fee recipients
contract LiquidationKeeper is IAutomationCompatible, BaseKeeper {
    bytes32 internal constant LIQUIDATION_KEEPER_LOCATION = keccak256(
        abi.encode(uint256(keccak256("fi.zaros.external.chainlink.keepers.LiquidationKeeper")) - 1)
    ) & ~bytes32(uint256(0xff));

    /// @custom:storage-location erc7201:fi.zaros.external.chainlink.LiquidationKeeper
    /// @param perpsEngine The address of the PerpsEngine contract.
    struct LiquidationKeeperStorage {
        IPerpsEngine perpsEngine;
        address marginCollateralRecipient;
        address liquidationFeeRecipient;
    }

    constructor() {
        _disableInitializers();
    }

    /// @notice {LiquidationKeeper} UUPS initializer.
    function initialize(
        address owner,
        address marginCollateralRecipient,
        address liquidationFeeRecipient
    )
        external
        initializer
    {
        __BaseKeeper_init(owner);

        if (marginCollateralRecipient == address(0)) {
            revert Errors.ZeroInput("marginCollateralRecipient");
        }

        if (liquidationFeeRecipient == address(0)) {
            revert Errors.ZeroInput("liquidationFeeRecipient");
        }

        LiquidationKeeperStorage storage self = _getLiquidationKeeperStorage();
        self.marginCollateralRecipient = marginCollateralRecipient;
        self.liquidationFeeRecipient = liquidationFeeRecipient;
    }

    function checkUpkeep(bytes calldata checkData)
        external
        view
        returns (bool upkeepNeeded, bytes memory performData)
    {
        (uint256 checkLowerBound, uint256 checkUpperBound, uint256 performLowerBound, uint256 performUpperBound) =
            abi.decode(checkData, (uint256, uint256, uint256, uint256));

        if (checkLowerBound > checkUpperBound || performLowerBound > performUpperBound) {
            revert Errors.InvalidBounds();
        }

        IPerpsEngine perpsEngine = _getLiquidationKeeperStorage().perpsEngine;
        uint128[] memory liquidatableAccountsIds =
            perpsEngine.checkLiquidatableAccounts(checkLowerBound, checkUpperBound);

        if (liquidatableAccountsIds.length == 0) {
            return (false, bytes(""));
        }

        uint128[] memory accountsToBeLiquidated;

        for (uint256 i = performLowerBound; i < performUpperBound; i++) {
            if (i < liquidatableAccountsIds.length) {
                accountsToBeLiquidated[i] = liquidatableAccountsIds[i];
            }
        }

        bytes memory extraData = abi.encode(accountsToBeLiquidated, address(this));

        return (true, extraData);
    }

    function setConfig(
        address perpsEngine,
        address marginCollateralRecipeint,
        address feeRecipient
    )
        external
        onlyOwner
    {
        LiquidationKeeperStorage storage self = _getLiquidationKeeperStorage();

        self.perpsEngine = IPerpsEngine(perpsEngine);
        self.marginCollateralRecipient = marginCollateralRecipeint;
        self.liquidationFeeRecipient = feeRecipient;
    }

    function performUpkeep(bytes calldata peformData) external override onlyForwarder {
        uint128[] memory accountsToBeLiquidated = abi.decode(peformData, (uint128[]));
        LiquidationKeeperStorage storage self = _getLiquidationKeeperStorage();
        (IPerpsEngine perpsEngine, address marginCollateralRecipient, address liquidationFeeRecipient) =
            (self.perpsEngine, self.marginCollateralRecipient, self.liquidationFeeRecipient);

        perpsEngine.liquidateAccounts(accountsToBeLiquidated, marginCollateralRecipient, liquidationFeeRecipient);
    }

    function _getLiquidationKeeperStorage() internal pure returns (LiquidationKeeperStorage storage self) {
        bytes32 slot = LIQUIDATION_KEEPER_LOCATION;

        assembly {
            self.slot := slot
        }
    }
}
