// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { IPerpsEngine } from "@zaros/perpetuals/PerpsEngine.sol";
import { BaseScript } from "./Base.s.sol";
import { ProtocolConfiguration } from "./utils/ProtocolConfiguration.sol";

// Forge dependencies
import { console } from "forge-std/console.sol";

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18 } from "@prb-math/SD59x18.sol";

contract CheckIfIsLiquidatable is BaseScript, ProtocolConfiguration {
    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/
    IPerpsEngine internal perpsEngine;

    function run() public broadcaster {
        perpsEngine = IPerpsEngine(payable(address(0x6B57b4c5812B8716df0c3682A903CcEfc94b21ad)));

        (SD59x18 marginBalanceUsdX18,, UD60x18 maintenanceMarginUsdX18,) = perpsEngine.getAccountMarginBreakdown(4485);

        bool isLiquidatable = maintenanceMarginUsdX18.intoSD59x18().gt(marginBalanceUsdX18);

        console.log("isLiquidatable: ", isLiquidatable);
    }
}
