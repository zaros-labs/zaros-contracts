// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { USDToken } from "@zaros/usd/USDToken.sol";
import { ZLPVault } from "@zaros/zlp/ZlpVault.sol";
import { MarketMakingEngineConfigurationBranch } from
    "@zaros/market-making/branches/MarketMakingEngineConfigurationBranch.sol";
import { MarketMakingEngine } from "@zaros/market-making/MarketMakingEngine.sol";
import { Collateral } from "@zaros/market-making/leaves/Collateral.sol";
import { Vault } from "@zaros/market-making/leaves/Vault.sol";

contract VaultRouterBranch_Depist_Test is Base_Test {
    ZLPVault zlpVault;

    function setUp() public virtual override {
        Base_Test.setUp();
        zlpVault = new ZLPVault();

        zlpVault.initialize(address(marketMakingEngine), 18, users.owner.account, wEth);

        Collateral.Data memory collateralData = Collateral.Data({
            creditRatio: 1.5e18 ,
            priceFeedHeartbeatSeconds: 120,
            priceAdapter: address(0),
            asset: address(wEth)
        });

        Vault.CreateParams memory params = Vault.CreateParams({
            vaultId: 1,
            depositCap: 2e18,
            withdrawalDelay: 1 days,
            indexToken: address(zlpVault),
            collateral: collateralData
        });

        marketMakingEngine.createVault(params);
    }



}