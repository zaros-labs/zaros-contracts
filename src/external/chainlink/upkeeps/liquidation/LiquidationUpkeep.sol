// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { IAutomationCompatible } from "@zaros/external/chainlink/interfaces/IAutomationCompatible.sol";
import { IPerpsEngine } from "@zaros/markets/perps/interfaces/IPerpsEngine.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { BaseUpkeep } from "../BaseUpkeep.sol";

contract LiquidationUpkeep is IAutomationCompatible, BaseUpkeep {
    bytes32 internal constant LIQUIDATION_UPKEEP_LOCATION = keccak256(
        abi.encode(uint256(keccak256("fi.zaros.external.chainlink.upkeeps.LiquidationUpkeep")) - 1)
    ) & ~bytes32(uint256(0xff));

    /// @custom:storage-location erc7201:fi.zaros.external.chainlink.LiquidationUpkeep
    /// @param perpsEngine The address of the PerpsEngine contract.
    struct LiquidationUpkeepStorage {
        IPerpsEngine perpsEngine;
    }

    constructor() {
        _disableInitializers();
    }

    /// @notice {LiquidationUpkeep} UUPS initializer.
    function initialize(address forwarder) external initializer {
        __BaseUpkeep_init(forwarder);
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

        IPerpsEngine perpsEngine = _getLiquidationUpkeepStorage().perpsEngine;
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

    function performUpkeep(bytes calldata peformData) external override onlyForwarder {
        (uint128[] memory accountsToBeLiquidated, address feeReceiver) = abi.decode(peformData, (uint128[], address));
        IPerpsEngine perpsEngine = _getLiquidationUpkeepStorage().perpsEngine;

        perpsEngine.liquidateAccounts(accountsToBeLiquidated, feeReceiver);
    }

    function _getLiquidationUpkeepStorage() internal pure returns (LiquidationUpkeepStorage storage self) {
        bytes32 slot = LIQUIDATION_UPKEEP_LOCATION;

        assembly {
            self.slot := slot
        }
    }
}
