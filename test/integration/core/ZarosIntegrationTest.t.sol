// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// // Zaros dependencies
// import { MockERC20 } from "test/mocks/MockERC20.sol";
// import { MockPriceFeed } from "test/mocks/MockPriceFeed.sol";
// import { MockERC20 } from "test/mocks/MockERC20.sol";
// import { Constants } from "@zaros/utils/Constants.sol";
// import { AccountNFT } from "@zaros/account-nft/AccountNFT.sol";
// import { LiquidityEngine } from "@zaros/liquidity/LiquidityEngine.sol";
// import { RewardDistributor } from "@zaros/reward-distributor/RewardDistributor.sol";
// import { CollateralConfig } from "@zaros/liquidity/storage/CollateralConfig.sol";

// // Forge dependencies
// import { Test } from "forge-std/Test.sol";

// /// @dev TODO: update to BTT
// contract LiquidityEngineIntegrationTest is Test {
//     /// @dev Contract addresses
//     address internal deployer = vm.addr(1);
//     MockERC20 internal sFrxEth;
//     MockERC20 internal usdc;
//     MockERC20 internal usdToken;
//     AccountNFT internal accountNft;
//     Zaros internal liquidityEngine;

//     /// @dev Configuration constants
//     uint80 public constant SFRXETH_ISSUANCE_RATIO = 200e18;
//     uint80 public constant SFRXETH_LIQUIDATION_RATIO = 150e18;
//     uint256 public constant SFRXETH_MIN_DELEGATION = 0.5e18;
//     uint256 public constant SFRXETH_DEPOSIT_CAP = 100_000e18;
//     uint80 public constant USDC_ISSUANCE_RATIO = 150e18;
//     uint80 public constant USDC_LIQUIDATION_RATIO = 110e18;
//     uint256 public constant USDC_MIN_DELEGATION = 1000e18;
//     uint256 public constant USDC_DEPOSIT_CAP = 100_000_000e6;
//     uint80 public constant LIQUIDATION_REWARD_RATIO = 0.05e18;
//     address public ethUsdOracle;
//     address public usdcUsdOracle;

//     function setUp() public {
//         startHoax(deployer);

//         sFrxEth = new MockERC20("Staked Frax Ether", "sfrxETH", 18);
//         usdc = new MockERC20("USD Coin", "USDC", 6);
//         usdToken = new MockERC20(100_000_000e18);
//         accountNft = new AccountNFT("Zaros Accounts", "ZRS-ACC");
//         liquidityEngine = new LiquidityEngine(address(accountNft), address(usdToken));
//         ethUsdOracle = address(new MockPriceFeed(8, 1000e8));
//         usdcUsdOracle = address(new MockPriceFeed(8, 1e8));

//         usdToken.transferOwnership(address(liquidityEngine));
//         accountNft.transferOwnership(address(liquidityEngine));

//         RewardDistributor sFrxEthRewardDistributor =
//             new RewardDistributor(address(liquidityEngine), address(usdToken), "sfrxETH Vault USDz
// Distributor");
//         RewardDistributor usdcRewardDistributor =
//             new RewardDistributor(address(liquidityEngine), address(usdToken), "USDC Vault USDz Distributor");

//         liquidityEngine.registerRewardDistributor(address(sFrxEth), address(sFrxEthRewardDistributor));
//         liquidityEngine.registerRewardDistributor(address(usdc), address(usdcRewardDistributor));

//         CollateralConfig.Data memory sFrxEthCollateralConfig = CollateralConfig.Data({
//             depositingEnabled: true,
//             issuanceRatio: SFRXETH_ISSUANCE_RATIO,
//             liquidationRatio: SFRXETH_LIQUIDATION_RATIO,
//             liquidationRewardRatio: LIQUIDATION_REWARD_RATIO,
//             oracle: ethUsdOracle,
//             tokenAddress: address(sFrxEth),
//             decimals: 18,
//             minDelegation: SFRXETH_MIN_DELEGATION,
//             depositCap: SFRXETH_DEPOSIT_CAP
//         });
//         CollateralConfig.Data memory usdcCollateralConfig = CollateralConfig.Data({
//             depositingEnabled: true,
//             issuanceRatio: USDC_ISSUANCE_RATIO,
//             liquidationRatio: USDC_ISSUANCE_RATIO,
//             liquidationRewardRatio: LIQUIDATION_REWARD_RATIO,
//             oracle: usdcUsdOracle,
//             tokenAddress: address(usdc),
//             decimals: 6,
//             minDelegation: USDC_MIN_DELEGATION,
//             depositCap: USDC_DEPOSIT_CAP
//         });

//         liquidityEngine.configureCollateral(sFrxEthCollateralConfig);
//         liquidityEngine.configureCollateral(usdcCollateralConfig);

//         // TODO: configure markets

//         // Enable Zaros' general features
//         liquidityEngine.setFeatureFlagAllowAll(Constants.CREATE_ACCOUNT_FEATURE_FLAG, true);
//         liquidityEngine.setFeatureFlagAllowAll(Constants.DEPOSIT_FEATURE_FLAG, true);
//         liquidityEngine.setFeatureFlagAllowAll(Constants.WITHDRAW_FEATURE_FLAG, true);
//         liquidityEngine.setFeatureFlagAllowAll(Constants.CLAIM_FEATURE_FLAG, true);
//         liquidityEngine.setFeatureFlagAllowAll(Constants.DELEGATE_FEATURE_FLAG, true);

//         sFrxEth.mint(deployer, 100_000_000e18);
//         usdc.mint(deployer, 100_000_000e6);

//         require(sFrxEth.approve(address(liquidityEngine), type(uint256).max), "approve failed");
//         require(usdc.approve(address(liquidityEngine), type(uint256).max), "approve failed");
//     }

//     function test_Integration_LpsCanDepositAndWithdraw() public {
//         uint256 amount = 100e18;
//         _createAccountDepositAndDelegate(address(sFrxEth), amount);
//         // Asserts that the Zaros account has the expected balance of sFrxEth
//         assertEq(sFrxEth.balanceOf(address(liquidityEngine)), amount);
//         // get account id of the user's first created account
//         // TODO: improve handling account id query
//         uint128 accountId = uint128(accountNft.tokenOfOwnerByIndex(deployer, 0));
//         _undelegateAndWithdraw(accountId, address(sFrxEth), amount);
//         assertEq(sFrxEth.balanceOf(address(liquidityEngine)), 0);
//     }

//     function _createAccountDepositAndDelegate(address collateralType, uint256 amount) internal {
//         bytes memory depositData = abi.encodeWithSelector(liquidityEngine.deposit.selector, collateralType,
// amount);
//         bytes memory delegateCollateralData =
//             abi.encodeWithSelector(liquidityEngine.delegateCollateral.selector, collateralType, amount);
//         bytes[] memory data = new bytes[](2);
//         data[0] = depositData;
//         data[1] = delegateCollateralData;

//         // Creates a new Zaros account and calls `deposit` and `delegateCollateral` in the same transaction
//         liquidityEngine.createAccountAndMulticall(data);
//     }

//     function _undelegateAndWithdraw(uint128 accountId, address collateralType, uint256 amount) internal {
//         (uint256 positionCollateralAmount,) = liquidityEngine.getPositionCollateral(accountId, collateralType);
//         uint256 newAmount = positionCollateralAmount - amount;
//         bytes memory delegateCollateralData =
//             abi.encodeWithSelector(liquidityEngine.delegateCollateral.selector, accountId, collateralType,
// newAmount);
//         bytes memory withdrawData = abi.encodeWithSelector(liquidityEngine.withdraw.selector, accountId,
// collateralType,
// amount);
//         bytes[] memory data = new bytes[](2);
//         data[0] = delegateCollateralData;
//         data[1] = withdrawData;

//         // Undelegates and withdraws the given amount of sFrxEth
//         liquidityEngine.multicall(data);
//     }
// }
