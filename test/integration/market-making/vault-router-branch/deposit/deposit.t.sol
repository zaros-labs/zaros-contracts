// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { Collateral } from "@zaros/market-making/leaves/Collateral.sol";
import { Vault } from "@zaros/market-making/leaves/Vault.sol";

contract VaultRouterBranch_Deposit_Test is Base_Test {

    function setUp() public virtual override {
        Base_Test.setUp();

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