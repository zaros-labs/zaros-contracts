// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { Vault } from "@zaros/market-making/leaves/Vault.sol";
import { Distribution } from "@zaros/market-making/leaves/Distribution.sol";
import { Collateral } from "@zaros/market-making/leaves/Collateral.sol";
import { FeeDistributionBranch } from "@zaros/market-making/branches/FeeDistributionBranch.sol";
import { MarketDebt } from "@zaros/market-making/leaves/MarketDebt.sol";

// Openzeppelin dependencies
import { IERC20, IERC20Metadata, IERC4626, SafeERC20 } from "@openzeppelin/token/ERC20/extensions/ERC4626.sol";

import "forge-std/console.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { sd59x18 } from "@prb-math/SD59x18.sol";

contract MarketMaking_FeeDistribution_receiveOrderFee is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVault();
        changePrank({ msgSender: address(perpsEngine) });

        marketMakingEngine.workaround_setPerpsEngineAddress(address(perpsEngine));
    }

    function test_RevertGiven_TheCallerIsNotPerpsEngine() external {
        changePrank({ msgSender: users.naruto.account });
        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.Unauthorized.selector, users.naruto.account ) });
        marketMakingEngine.receiveOrderFee(1, address(wBtc), 10e8);
    }

    modifier givenTheCallerIsPerpEngine() {
        _;
    }

    function test_RevertGiven_TheAmountIsZero() external givenTheCallerIsPerpEngine  {
        // it should revert
        Vault.Data storage vault = Vault.load(1);
        Collateral.Data storage collateral = vault.collateral;
        collateral.asset = address(wEth);
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "amount") });
        marketMakingEngine.receiveOrderFee(1, address(wEth), 0);
    }

    function test_GivenTheAmountIsNotZero() external givenTheCallerIsPerpEngine  {
        address thisContractAddr = 0x763d32e23401eAD917023881999Dbd38Aa76C25F;
        
        deal(address(wEth), address(perpsEngine), 20e18);

        Vault.Data storage vault = Vault.load(1);
        Collateral.Data storage collateral = vault.collateral;
        collateral.asset = address(wEth);
        IERC20(address(wEth)).approve(thisContractAddr, 20e18);

       // it should emit event { OrderFeeReceived }
        vm.expectEmit();
        emit FeeDistributionBranch.OrderFeeReceived(
            address(wEth), 5e18
        );
        // it should receive tokens
        marketMakingEngine.receiveOrderFee(1, address(wEth), 5e18);
        assertEq(IERC20(address(wEth)).balanceOf(thisContractAddr), 5e18);
    }
}
