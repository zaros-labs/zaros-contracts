// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { IAutomationCompatible } from "@zaros/external/chainlink/interfaces/IAutomationCompatible.sol";
import { IPerpsEngine } from "@zaros/markets/perps/interfaces/IPerpsEngine.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { BaseKeeper } from "../BaseKeeper.sol";

contract LiquidationKeeper is IAutomationCompatible, BaseKeeper {
    bytes32 internal constant LIQUIDATION_KEEPER_LOCATION = keccak256(
        abi.encode(uint256(keccak256("fi.zaros.external.chainlink.keepers.LiquidationKeeper")) - 1)
    ) & ~bytes32(uint256(0xff));

    /// @custom:storage-location erc7201:fi.zaros.external.chainlink.LiquidationKeeper
    /// @param perpsEngine The address of the PerpsEngine contract.
    struct LiquidationKeeperStorage {
        IPerpsEngine perpsEngine;
    }

    constructor() {
        _disableInitializers();
    }

    /// @notice {LiquidationKeeper} UUPS initializer.
    function initialize(address owner) external initializer {
        __BaseKeeper_init(owner);
    }

    function checkKeeper(bytes calldata checkData)
        external
        view
        returns (bool keeperNeeded, bytes memory performData)
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

    function performKeeper(bytes calldata peformData) external override onlyForwarder {
        (uint128[] memory accountsToBeLiquidated, address feeReceiver) = abi.decode(peformData, (uint128[], address));
        IPerpsEngine perpsEngine = _getLiquidationKeeperStorage().perpsEngine;

        perpsEngine.liquidateAccounts(accountsToBeLiquidated, feeReceiver);
    }

    function _getLiquidationKeeperStorage() internal pure returns (LiquidationKeeperStorage storage self) {
        bytes32 slot = LIQUIDATION_KEEPER_LOCATION;

        assembly {
            self.slot := slot
        }
    }
}
