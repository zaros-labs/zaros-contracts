// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { ILogAutomation, Log as AutomationLog } from "@zaros/external/interfaces/chainlink/ILogAutomation.sol";
import { IStreamsLookupCompatible } from "@zaros/external/interfaces/chainlink/IStreamsLookupCompatible.sol";
import { ISettlementEngineModule } from "../interfaces/ISettlementEngineModule.sol";

abstract contract SettlementEngineModule is ISettlementEngineModule, ILogAutomation, IStreamsLookupCompatible {
    function checkLog(
        AutomationLog calldata log,
        bytes calldata checkData
    )
        external
        view
        returns (bool upkeepNeeded, bytes memory performData)
    { }

    function checkCallback(
        bytes[] memory values,
        bytes memory extraData
    )
        external
        view
        returns (bool upkeepNeeded, bytes memory performData)
    { }

    function performUpkeep(bytes calldata performData) external { }

    function _settleOrder() internal { }
}
