// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { Vault } from "@zaros/market-making/leaves/Vault.sol";
import { Collateral } from "@zaros/market-making/leaves/Collateral.sol";
import { FeeDistributionBranch } from "@zaros/market-making/branches/FeeDistributionBranch.sol";

// Openzeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { sd59x18 } from "@prb-math/SD59x18.sol";

contract ReceiveOrderFee_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID);
        changePrank({ msgSender: address(perpsEngine) });

        marketMakingEngine.workaround_setPerpsEngineAddress(address(perpsEngine));

        marketMakingEngine.workaround_setMarketId(1, 1);
        
        marketMakingEngine.workaround_Collateral_setParams(address(wEth), 2e18, 120, true, 18, address(0));
    }

    function test_RevertGiven_TheCallerIsNotMarketMakingEngine() external {
        changePrank({ msgSender: users.naruto.account });
        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.Unauthorized.selector, users.naruto.account ) });
        marketMakingEngine.receiveOrderFee(1, address(wBtc), 10e8);
    }

    modifier givenTheCallerIsMarketMakingEngine() {
        _;
    }

    function testFuzz_RevertWhen_MarketDoesNotExist() external givenTheCallerIsMarketMakingEngine {
        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.UnrecognisedMarket.selector) });
        marketMakingEngine.receiveOrderFee(0, address(wBtc), 10e18);
    }

    modifier whenMarketExist() {
        _;
    }

    function test_RevertGiven_AssetIsNotEnabled() external givenTheCallerIsMarketMakingEngine whenMarketExist {
        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.CollateralDisabled.selector, address(0) ) });
        marketMakingEngine.receiveOrderFee(1, address(usdz), 10e8);
    }

    modifier givenAssetIsEnabled() {
        _;
    }

    function testFuzz_RevertWhen_TheAmountIsZero()
        external
        givenTheCallerIsMarketMakingEngine
        whenMarketExist
        givenAssetIsEnabled
    {
        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "amount") });
        marketMakingEngine.receiveOrderFee(1, address(wEth), 0);
    }

    function test_WhenTheAmountIsNotZero()
        external
        givenTheCallerIsMarketMakingEngine
        whenMarketExist
        givenAssetIsEnabled
    {
        deal(address(wEth), address(perpsEngine), 20e18);

        Vault.Data storage vault = Vault.load(1);
        Collateral.Data storage collateral = vault.collateral;
        collateral.asset = address(wEth);
        IERC20(address(wEth)).approve(address(marketMakingEngine), 20e18);

        // it should emit event { LogReceiveOrderFee }
        vm.expectEmit();
        emit FeeDistributionBranch.LogReceiveOrderFee(
            address(wEth), 5e18
        );

        // it should receive tokens
        marketMakingEngine.receiveOrderFee(1, address(wEth), 5e18);
        assertEq(IERC20(address(wEth)).balanceOf(address(marketMakingEngine)), 5e18);
    }
}
