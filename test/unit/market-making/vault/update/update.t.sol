// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";

// Zaros dependencies source
import { Vault } from "@zaros/market-making/leaves/Vault.sol";
import { Collateral } from "@zaros/market-making/leaves/Collateral.sol";
import { Errors } from "@zaros/utils/Errors.sol";

contract Vault_Update_Unit_Test is Base_Test {

    function setUp() public virtual override {
        Base_Test.setUp();
    }

    function test_RevertWhen_UpdateIsPassedZeroId() external {
        Collateral.Data memory collateralData = Collateral.Data({
            creditRatio: 1.5e18,
            priceFeedHeartbeatSeconds: 120,
            priceAdapter: address(0),
            asset: address(wEth),
            isEnabled: true,
            decimals: 8
        });

        Vault.UpdateParams memory params = Vault.UpdateParams({
            vaultId: 0,
            depositCap: 1,
            withdrawalDelay: 1,
            collateral: collateralData
        });

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroInput.selector, "vaultId"));
        marketMakingEngine.exposed_Vault_update(params);
    }
}
