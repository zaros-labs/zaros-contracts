// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { IPerpsEngine } from "@zaros/perpetuals/PerpsEngine.sol";
import { BaseScript } from "../Base.s.sol";

// Forge dependencies
import { console } from "forge-std/console.sol";

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18 } from "@prb-math/SD59x18.sol";

contract Test is BaseScript {
    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/
    IPerpsEngine internal perpsEngine;

    function run() public broadcaster {
        perpsEngine = IPerpsEngine(payable(address(0x6f7b7e54a643E1285004AaCA95f3B2e6F5bcC1f3)));

        (SD59x18 marginBalanceUsdX18,, UD60x18 maintenanceMarginUsdX18,) = perpsEngine.getAccountMarginBreakdown(3);

        bool isLiquidatable = maintenanceMarginUsdX18.intoSD59x18().gt(marginBalanceUsdX18);

        console.log("isLiquidatable: ", isLiquidatable);
    }
}
