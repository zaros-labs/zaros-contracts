// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { BaseScript } from "../Base.s.sol";
import { IPerpsEngineTestnet } from "testnet/PerpsEngineTestnet.sol";

// PRB Math dependencies
import { UD60x18, convert } from "@prb-math/UD60x18.sol";


// ATTENTION: It necessary add the `removeUsdz` function before running this script and remove after
contract RemoveUsdz is BaseScript {
    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/
    address internal perpsEngine;

    function run() public broadcaster {
        perpsEngine = address(0x6f7b7e54a643E1285004AaCA95f3B2e6F5bcC1f3);

        uint256[] memory tradingAccounts = new uint256[](2);
        tradingAccounts[0] = 4;
        tradingAccounts[1] = 12846;

        UD60x18[] memory amounts = new UD60x18[](2);
        amounts[0] = convert(1387877397728315520935);
        amounts[1] = convert(51516067196188204951);

        IPerpsEngineTestnet(perpsEngine).removeUsdz(tradingAccounts, amounts);
    }
}

