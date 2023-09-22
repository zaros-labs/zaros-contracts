// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { AccountNFT } from "@zaros/account-nft/AccountNFT.sol";
import { PerpsEngine } from "@zaros/markets/perps/PerpsEngine.sol";
import { ZarosUSD } from "@zaros/usd/ZarosUSD.sol";
import { BaseScript } from "./Base.s.sol";

// Forge dependencies
import "forge-std/console.sol";

contract DeployAlphaPerps is BaseScript {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/
    address internal mockChainlinkVerifier = address(1);
    address internal mockRewardDistributorAddress = address(2);
    address internal mockZarosAddress = address(3);

    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/
    AccountNFT internal perpsAccountToken;
    ZarosUSD internal usdToken;
    PerpsEngine internal perpsEngine;

    function run() public broadcaster {
        perpsAccountToken = new AccountNFT("Zaros Trading Accounts", "ZRS-TRADE-ACC");
        usdToken = ZarosUSD(vm.envAddress("ZRSUSD"));
        perpsEngine = new PerpsEngine(mockChainlinkVerifier,
        address(perpsAccountToken), mockRewardDistributorAddress, address(usdToken), mockZarosAddress);
        perpsEngine.setIsCollateralEnabled(address(usdToken), true);
    }

    function configureContracts() internal {
        perpsEngine.setIsCollateralEnabled(address(usdToken), true);
    }
}
