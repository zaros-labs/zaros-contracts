// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { IPerpsEngine } from "@zaros/perpetuals/PerpsEngine.sol";
import { BaseScript } from "./Base.s.sol";

// Forge dependencies
import { console } from "forge-std/console.sol";

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18 } from "@prb-math/SD59x18.sol";

// forge script script/DebugTradingAccount.s.sol --rpc-url arbitrum_sepolia --broadcast -vvvv

contract DebugTradingAccount is BaseScript {
    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/
    IPerpsEngine internal perpsEngine;

    function run() public broadcaster {
        perpsEngine = IPerpsEngine(payable(address(0x6f7b7e54a643E1285004AaCA95f3B2e6F5bcC1f3)));

        (
            SD59x18 marginBalanceUsdX18,
            UD60x18 initialMarginUsdX18,
            UD60x18 maintenanceMarginUsdX18,
            SD59x18 availableMarginUsdX18
        ) = perpsEngine.getAccountMarginBreakdown(26_782);
        console.log("----------------26782-----------------");
        console.log("marginBalanceUsdX18: ", marginBalanceUsdX18.intoInt256());
        console.log("initialMarginUsdX18: ", initialMarginUsdX18.intoUint256());
        console.log("maintenanceMarginUsdX18: ", maintenanceMarginUsdX18.intoUint256());
        console.log("availableMarginUsdX18: ", availableMarginUsdX18.intoUint256());

        // uint128[] memory liquidatableAccountsIds = perpsEngine.checkLiquidatableAccounts(1, 26506);

        // console.log("checkLiquidatableAccounts");
        // for (uint256 i; i < liquidatableAccountsIds.length; i++) {
        //     console.log(liquidatableAccountsIds[i]);
        // }

        // console.log("liquidateAccounts");
        // perpsEngine.liquidateAccounts(liquidatableAccountsIds);

        //         ( marginBalanceUsdX18,,  maintenanceMarginUsdX18,) = perpsEngine.getAccountMarginBreakdown(11146);
        // console.log("----------------11146-----------------");
        // console.log("marginBalanceUsdX18: ", marginBalanceUsdX18.intoInt256());
        // console.log("maintenanceMarginUsdX18: ", maintenanceMarginUsdX18.intoUint256());

        //         ( marginBalanceUsdX18,,  maintenanceMarginUsdX18,) = perpsEngine.getAccountMarginBreakdown(10165);
        // console.log("----------------10165-----------------");
        // console.log("marginBalanceUsdX18: ", marginBalanceUsdX18.intoInt256());
        // console.log("maintenanceMarginUsdX18: ", maintenanceMarginUsdX18.intoUint256());

        //         ( marginBalanceUsdX18,,  maintenanceMarginUsdX18,) = perpsEngine.getAccountMarginBreakdown( 11135);
        // console.log("---------------- 11135-----------------");
        // console.log("marginBalanceUsdX18: ", marginBalanceUsdX18.intoInt256());
        // console.log("maintenanceMarginUsdX18: ", maintenanceMarginUsdX18.intoUint256());

        //         ( marginBalanceUsdX18,,  maintenanceMarginUsdX18,) = perpsEngine.getAccountMarginBreakdown(9475);
        // console.log("----------------9475-----------------");
        // console.log("marginBalanceUsdX18: ", marginBalanceUsdX18.intoInt256());
        // console.log("maintenanceMarginUsdX18: ", maintenanceMarginUsdX18.intoUint256());

        // bool isLiquidatable = maintenanceMarginUsdX18.intoSD59x18().gt(marginBalanceUsdX18);

        // console.log("isLiquidatable: ", isLiquidatable);
    }
}
