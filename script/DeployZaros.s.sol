// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
// import { BaseScript } from "./Base.s.sol";
// import { Constants } from "@zaros/utils/Constants.sol";
// import { AccountNFT } from "@zaros/account-nft/AccountNFT.sol";
// import { USDToken } from "@zaros/usd/USDToken.sol";
// import { LiquidityEngine } from "@zaros/liquidity/LiquidityEngine.sol";
// import { CollateralConfig } from "@zaros/liquidity/storage/CollateralConfig.sol";
// import { RewardDistributor } from "@zaros/reward-distributor/RewardDistributor.sol";
// import { BalancerUSDCStrategy } from "@zaros/strategies/BalancerUSDCStrategy.sol";
// import { IPerpsEngine } from "@zaros/markets/perps/interfaces/IPerpsEngine.sol";
// import { PerpMarket } from "@zaros/markets/perps/PerpMarket.sol";
// import { OrderFees } from "@zaros/markets/perps/storage/OrderFees.sol";

// // Open Zeppelin dependencies
// import { IERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";

// import "forge-std/console.sol";

// contract DeployZaros is BaseScript {
//     uint80 public constant SFRXETH_ISSUANCE_RATIO = 200e18;
//     uint80 public constant SFRXETH_LIQUIDATION_RATIO = 150e18;
//     uint256 public constant SFRXETH_MIN_DELEGATION = 0.5e18;
//     uint256 public constant SFRXETH_DEPOSIT_CAP = 100_000e18;
//     uint80 public constant USDC_ISSUANCE_RATIO = 150e18;
//     uint80 public constant USDC_LIQUIDATION_RATIO = 110e18;
//     uint256 public constant USDC_MIN_DELEGATION = 1000e18;
//     uint256 public constant USDC_DEPOSIT_CAP = 100_000_000e6;
//     uint80 public constant LIQUIDATION_REWARD_RATIO = 0.05e18;
//     uint128 public constant USDC_STRATEGY_BORROW_CAP = type(uint128).max;
//     uint256 public constant PERPS_MAX_LEVERAGE = 50e18;
//     OrderFees.Data public orderFees = OrderFees.Data({ makerFee: 0.04e18, takerFee: 0.08e18 });

//     function run() public broadcaster {
//         IERC20 sFrxEth = IERC20(vm.envAddress("SFRXETH"));
//         IERC20 usdc = IERC20(vm.envAddress("USDC"));
//         USDToken usdToken = USDToken(vm.envAddress("USDZ"));
//         AccountNFT accountNft = new AccountNFT("Zaros Accounts", "ZRS-ACC");
//         LiquidityEngine liquidityEngine = new LiquidityEngine(address(accountNft), address(usdToken));
//         BalancerUSDCStrategy balancerUsdcStrategy =
//         new BalancerUSDCStrategy(address(liquidityEngine), address(usdc), address(usdToken),
//         vm.envAddress("BALANCER_VAULT"), vm.envBytes32("USDZ_USDC_POOL_ID"));
//         address ethUsdOracle = vm.envAddress("ETH_USD_ORACLE");
//         address usdcUsdOracle = vm.envAddress("USDC_USD_ORACLE");

//         usdToken.addToFeatureFlagAllowlist(Constants.MINT_FEATURE_FLAG, address(liquidityEngine));
//         usdToken.addToFeatureFlagAllowlist(Constants.BURN_FEATURE_FLAG, address(liquidityEngine));
//         usdToken.addToFeatureFlagAllowlist(Constants.MINT_FEATURE_FLAG, deployer);
//         usdToken.addToFeatureFlagAllowlist(Constants.BURN_FEATURE_FLAG, deployer);
//         accountNft.transferOwnership(address(liquidityEngine));

//         RewardDistributor rewardDistributor =
//             new RewardDistributor(address(liquidityEngine), address(usdToken), "Zaros USDz Distributor");

//         liquidityEngine.registerRewardDistributor(address(sFrxEth), address(rewardDistributor));
//         liquidityEngine.registerRewardDistributor(address(usdc), address(rewardDistributor));
//         // TODO: uncomment
//         // liquidityEngine.registerStrategy(address(usdc), address(balancerUsdcStrategy),
// USDC_STRATEGY_BORROW_CAP);

//         {
//             // TODO: use correct accountNft
//             PerpsEngine perpsEngine =
//                 new PerpsEngine(payable(address(accountNft), address(liquidityEngine),
// address(rewardDistributor));

//             console.log("Perps Vault: ");
//             console.log(address(perpsEngine));

//             PerpMarket sFrxEthPerpMarket = new PerpMarket("sfrxETH-USD Perps Market", "SFRXETH-USD PERP",
//             ethUsdOracle, address(perpsEngine), PERPS_MAX_LEVERAGE, orderFees);

//             console.log("Perps Market: ");
//             console.log(address(sFrxEthPerpMarket));

//             // perpsEngine.setSupportedMarket(address(sFrxEthPerpMarket), true);
//             perpsEngine.setIsCollateralEnabled(address(usdToken), true);
//         }

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

//         console.log("Zaros: ");
//         console.log(address(liquidityEngine));
//         console.log("Account NFT: ");
//         console.log(address(accountNft));
//         console.log("Balancer USDC Strategy: ");
//         console.log(address(balancerUsdcStrategy));
//         console.log("Reward Distributor: ");
//         console.log(address(rewardDistributor));
//     }
// }
