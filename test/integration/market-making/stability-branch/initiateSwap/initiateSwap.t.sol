// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { StabilityBranch } from "@zaros/market-making/branches/StabilityBranch.sol";
import { UsdTokenSwap } from "@zaros/market-making/leaves/UsdTokenSwap.sol";
import { Collateral } from "@zaros/market-making/leaves/Collateral.sol";

contract InitiateSwap_Integration_Test is Base_Test {
    using Collateral for Collateral.Data;
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID);
        marketMakingEngine.configureEngine(address(marketMakingEngine), address(usdToken), true);
        changePrank({ msgSender: users.naruto.account });
    }

    function test_RevertWhen_VaultIdsAndAmountsInArraysLengthMissmatch() external {
        uint128[] memory vaultIds = new uint128[](1);
        uint256[] memory amountsIn = new uint256[](2);
        uint256[] memory minAmountsOut = new uint256[](3);

        // it should revert
        vm.expectRevert(
            abi.encodeWithSelector(Errors.ArrayLengthMismatch.selector, vaultIds.length, amountsIn.length)
        );

        marketMakingEngine.initiateSwap(vaultIds, amountsIn, minAmountsOut);
    }

    modifier whenVaultIdsAndAmountsInArraysLengthMatch() {
        _;
    }

    function test_RevertWhen_AmountsInAndMinAmountsOutArraysLengthMissmatch()
        external
        whenVaultIdsAndAmountsInArraysLengthMatch
    {
        uint128[] memory vaultIds = new uint128[](2);
        uint256[] memory amountsIn = new uint256[](2);
        uint256[] memory minAmountsOut = new uint256[](3);

        // it should revert
        vm.expectRevert(
            abi.encodeWithSelector(Errors.ArrayLengthMismatch.selector, amountsIn.length, minAmountsOut.length)
        );

        marketMakingEngine.initiateSwap(vaultIds, amountsIn, minAmountsOut);
    }

    modifier whenAmountsInAndMinAmountsOutArraysLengthMatch() {
        _;
    }

    function test_RevertWhen_CollateralIsDisabled(uint256 vaultId)
        external
        whenVaultIdsAndAmountsInArraysLengthMatch
        whenAmountsInAndMinAmountsOutArraysLengthMatch
    {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        bool isEnabled = false;

        changePrank({ msgSender: users.owner.account });
        marketMakingEngine.configureCollateral(fuzzVaultConfig.asset, address(8), 1e8, isEnabled, 8);
        changePrank({ msgSender: users.naruto.account });

        uint128[] memory vaultIds = new uint128[](2);
        uint256[] memory amountsIn = new uint256[](2);
        uint256[] memory minAmountsOut = new uint256[](2);

        vaultIds[0] = fuzzVaultConfig.vaultId;
        vaultIds[1] = fuzzVaultConfig.vaultId;

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.CollateralDisabled.selector, fuzzVaultConfig.asset));

        marketMakingEngine.initiateSwap(vaultIds, amountsIn, minAmountsOut);
    }

    modifier whenCollateralIsEnabled() {
        _;
    }

    function testFuzz_RevertWhen_CollateralAssetsOfVaultsMissmatch()
        external
        whenVaultIdsAndAmountsInArraysLengthMatch
        whenAmountsInAndMinAmountsOutArraysLengthMatch
        whenCollateralIsEnabled
    {
        uint128[] memory vaultIds = new uint128[](2);
        uint256[] memory amountsIn = new uint256[](2);
        uint256[] memory minAmountsOut = new uint256[](2);

        vaultIds[0] = INITIAL_VAULT_ID;
        vaultIds[1] = FINAL_VAULT_ID;

        address asset0 = marketMakingEngine.workaround_Vault_getVaultAsset(INITIAL_VAULT_ID);
        address asset1 = marketMakingEngine.workaround_Vault_getVaultAsset(FINAL_VAULT_ID);

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.MissmatchingCollateralAssets.selector, asset1, asset0));

        marketMakingEngine.initiateSwap(vaultIds, amountsIn, minAmountsOut);
    }

    function test_WhenCollateralAssetsOfVaultsMatch(
        uint256 vaultId,
        uint256 swapAmount
    )
        external
        whenVaultIdsAndAmountsInArraysLengthMatch
        whenAmountsInAndMinAmountsOutArraysLengthMatch
        whenCollateralIsEnabled
    {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        swapAmount = bound({ x: swapAmount, min: 1e18, max: type(uint128).max });

        uint128[] memory vaultIds = new uint128[](1);
        vaultIds[0] = fuzzVaultConfig.vaultId;

        uint256[] memory amountsIn = new uint256[](1);
        amountsIn[0] = swapAmount;

        uint256[] memory minAmountsOut = new uint256[](1);

        deal({ token: address(usdToken), to: users.naruto.account, give: swapAmount });

        uint128 swapRequestId = 1;

        // it shoud emit {LogInitiateSwap} event
        vm.expectEmit({ emitter: address(marketMakingEngine) });
        emit StabilityBranch.LogInitiateSwap(users.naruto.account, swapRequestId);

        marketMakingEngine.initiateSwap(vaultIds, amountsIn, minAmountsOut);

        // it shoud create new usd token swap request
        UsdTokenSwap.SwapRequest memory request =
            marketMakingEngine.getSwapRequest(users.naruto.account, swapRequestId);

        assertGt(request.vaultId, 0);
        assertGt(request.deadline, 0);
        assertFalse(request.processed);
    }
}
