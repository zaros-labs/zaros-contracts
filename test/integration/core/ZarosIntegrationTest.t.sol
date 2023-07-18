// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { MockERC20 } from "..../../test/mocks/MockERC20.sol";
import { MockZarosUSD } from "..../../test/mocks/MockZarosUSD.sol";
import { Constants } from "@zaros/utils/Constants.sol";
import { AccountNFT } from "@zaros/account-nft/AccountNFT.sol";
import { Zaros } from "@zaros/core/Zaros.sol";
import { RewardDistributor } from "@zaros/reward-distributor/RewardDistributor.sol";
import { CollateralConfig } from "@zaros/core/storage/CollateralConfig.sol";

// Forge dependencies
import { Test } from "forge-std/Test.sol";

contract ZarosIntegrationTest is Test {
    /// @dev Contract addresses
    address internal deployer = vm.addr(1);
    MockERC20 internal sFrxEth;
    MockERC20 internal usdc;
    MockZarosUSD internal zrsUsd;
    AccountNFT internal accountNft;
    Zaros internal zaros;

    /// @dev Configuration constants
    uint256 public constant sFrxEthIssuanceRatio = 200e18;
    uint256 public constant usdcIssuanceRatio = 150e18;
    uint256 public constant sFrxEthLiquidationRatio = 150e18;
    uint256 public constant usdcLiquidationRatio = 110e18;
    uint256 public constant liquidationRewardRatio = 0.05e18;

    function setUp() public {
        startHoax(deployer);

        sFrxEth = new MockERC20("Staked Frax Ether", "sfrxETH", 18);
        usdc = new MockERC20("USD Coin", "USDC", 6);
        zrsUsd = new MockZarosUSD(100_000_000e18);
        accountNft = new AccountNFT();
        zaros = new Zaros(address(accountNft), address(zrsUsd));

        zrsUsd.transferOwnership(address(zaros));
        accountNft.transferOwnership(address(zaros));

        RewardDistributor sFrxEthRewardDistributor =
            new RewardDistributor(address(zaros), address(zrsUsd), "sfrxETH Vault zrsUSD Distributor");
        RewardDistributor usdcRewardDistributor =
            new RewardDistributor(address(zaros), address(zrsUsd), "USDC Vault zrsUSD Distributor");

        zaros.registerRewardDistributor(address(sFrxEth), address(sFrxEthRewardDistributor));
        zaros.registerRewardDistributor(address(usdc), address(usdcRewardDistributor));

        CollateralConfig.Data memory sFrxEthCollateralConfig = CollateralConfig.Data({
            depositingEnabled: true,
            issuanceRatio: sFrxEthIssuanceRatio,
            liquidationRatio: sFrxEthLiquidationRatio,
            liquidationRewardRatio: liquidationRewardRatio,
            // TODO: update this
            oracle: address(0),
            tokenAddress: address(sFrxEth),
            decimals: 18,
            minDelegation: 0.5e18
        });
        CollateralConfig.Data memory usdcCollateralConfig = CollateralConfig.Data({
            depositingEnabled: true,
            issuanceRatio: usdcIssuanceRatio,
            liquidationRatio: usdcIssuanceRatio,
            liquidationRewardRatio: liquidationRewardRatio,
            // TODO: update this
            oracle: address(0),
            tokenAddress: address(usdc),
            decimals: 6,
            minDelegation: 1000e18
        });

        zaros.configureCollateral(sFrxEthCollateralConfig);
        zaros.configureCollateral(usdcCollateralConfig);

        // TODO: configure markets

        // Enable Zaros' general features
        zaros.setFeatureFlagAllowAll(Constants.CREATE_ACCOUNT_FEATURE_FLAG, true);
        zaros.setFeatureFlagAllowAll(Constants.DEPOSIT_FEATURE_FLAG, true);
        zaros.setFeatureFlagAllowAll(Constants.WITHDRAW_FEATURE_FLAG, true);
        zaros.setFeatureFlagAllowAll(Constants.CLAIM_FEATURE_FLAG, true);
        zaros.setFeatureFlagAllowAll(Constants.DELEGATE_FEATURE_FLAG, true);

        // Enable Zaros' permissioned features
        zaros.addToFeatureFlagAllowlist(Constants.MARKET_FEATURE_FLAG, deployer);
        zaros.addToFeatureFlagAllowlist(Constants.STRATEGY_FEATURE_FLAG, deployer);

        sFrxEth.mint(deployer, 100_000_000e18);
        usdc.mint(deployer, 100_000_000e6);

        sFrxEth.approve(address(zaros), type(uint256).max);
        usdc.approve(address(zaros), type(uint256).max);
    }

    function test_Integration_LpsCanDepositAndWithdraw() public {
        uint256 amount = 100e18;
        _createAccountDepositAndDelegate(address(sFrxEth), amount);
        // Asserts that the Zaros account has the expected balance of sFrxEth
        assertEq(sFrxEth.balanceOf(address(zaros)), amount);
        // get account id of the user's first created account
        // TODO: improve handling account id query
        uint128 accountId = uint128(accountNft.tokenOfOwnerByIndex(deployer, 0));
        _undelegateAndWithdraw(accountId, address(sFrxEth), amount);
        assertEq(sFrxEth.balanceOf(address(zaros)), 0);
    }

    function _createAccountDepositAndDelegate(address collateralType, uint256 amount) internal {
        bytes memory depositData = abi.encodeWithSelector(zaros.deposit.selector, collateralType, amount);
        bytes memory delegateCollateralData =
            abi.encodeWithSelector(zaros.delegateCollateral.selector, collateralType, amount);
        bytes[] memory data = new bytes[](2);
        data[0] = depositData;
        data[1] = delegateCollateralData;

        // Creates a new Zaros account and calls `deposit` and `delegateCollateral` in the same transaction
        zaros.createAccountAndMulticall(data);
    }

    function _undelegateAndWithdraw(uint128 accountId, address collateralType, uint256 amount) internal {
        (uint256 positionCollateralAmount, uint256 positionCollateralValue) =
            zaros.getPositionCollateral(accountId, collateralType);
        uint256 newAmount = positionCollateralAmount - amount;
        bytes memory delegateCollateralData =
            abi.encodeWithSelector(zaros.delegateCollateral.selector, accountId, collateralType, newAmount);
        bytes memory withdrawData = abi.encodeWithSelector(zaros.withdraw.selector, accountId, collateralType, amount);
        bytes[] memory data = new bytes[](2);
        data[0] = delegateCollateralData;
        data[1] = withdrawData;

        // Undelegates and withdraws the given amount of sFrxEth
        zaros.multicall(data);
    }
}
