// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { IAutomationCompatible } from "@zaros/external/chainlink/upkeeps/liquidation/LiquidationUpkeep.sol";
import { BaseUpkeeo } from "../BaseUpkeep.sol";

contract LiquidationUpkeep is IAutomationCompatible, IStreamsLookupCompatible, BaseUpkeep {
    constructor() {
        _disableInitializers();
    }

    /// @notice {LiquidationUpkeep} UUPS initializer.
    function initialize(address forwarder) external initializer {
        __BaseUpkeep_init(forwarder);
    }

    function checkUpkeep(bytes calldata checkData) external returns (bool upkeepNeeded, bytes memory performData) external {
        (uint256 checkLowerBound, uint256 checkUpperBound, uint256 performLowerBound, uint256 performUpperBound) =
        abi.decode(checkData, (uint256, uint256, uint256, uint256));

        if (checkLowerBound > checkUpperBound || performLowerBound > performUpperBound) {
            revert Errors.InvalidBounds();
        }



    }

    function checkCallback(
        bytes[] calldata values,
        bytes calldata extraData
    )
        external
        pure
        override
        returns (bool upkeepNeeded, bytes memory performData) {}

    function performUpkeep(bytes calldata peformData) external override onlyForwarder {

    }
}
