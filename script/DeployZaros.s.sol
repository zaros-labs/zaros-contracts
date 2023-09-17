// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

// Zaros dependencies
// import { BaseScript } from "./Base.s.sol";
// import { Constants } from "@zaros/utils/Constants.sol";
// import { AccountNFT } from "@zaros/account-nft/AccountNFT.sol";
// import { ZarosUSD } from "@zaros/usd/ZarosUSD.sol";
// import { Zaros } from "@zaros/core/Zaros.sol";
// import { CollateralConfig } from "@zaros/core/storage/CollateralConfig.sol";
// import { RewardDistributor } from "@zaros/reward-distributor/RewardDistributor.sol";
// import { BalancerUSDCStrategy } from "@zaros/strategies/BalancerUSDCStrategy.sol";
// import { PerpsExchange } from "@zaros/markets/perps/PerpsExchange.sol";
// import { PerpsMarket } from "@zaros/markets/perps/PerpsMarket.sol";
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
//         ZarosUSD zrsUsd = ZarosUSD(vm.envAddress("ZRSUSD"));
//         AccountNFT accountNft = new AccountNFT("Zaros Accounts", "ZRS-ACC");
//         Zaros zaros = new Zaros(address(accountNft), address(zrsUsd));
//         BalancerUSDCStrategy balancerUsdcStrategy =
//         new BalancerUSDCStrategy(address(zaros), address(usdc), address(zrsUsd),
//         vm.envAddress("BALANCER_VAULT"), vm.envBytes32("ZRSUSD_USDC_POOL_ID"));
//         address ethUsdOracle = vm.envAddress("ETH_USD_ORACLE");
//         address usdcUsdOracle = vm.envAddress("USDC_USD_ORACLE");

//         zrsUsd.addToFeatureFlagAllowlist(Constants.MINT_FEATURE_FLAG, address(zaros));
//         zrsUsd.addToFeatureFlagAllowlist(Constants.BURN_FEATURE_FLAG, address(zaros));
//         zrsUsd.addToFeatureFlagAllowlist(Constants.MINT_FEATURE_FLAG, deployer);
//         zrsUsd.addToFeatureFlagAllowlist(Constants.BURN_FEATURE_FLAG, deployer);
//         accountNft.transferOwnership(address(zaros));

//         RewardDistributor rewardDistributor =
//             new RewardDistributor(address(zaros), address(zrsUsd), "Zaros zrsUSD Distributor");

//         zaros.registerRewardDistributor(address(sFrxEth), address(rewardDistributor));
//         zaros.registerRewardDistributor(address(usdc), address(rewardDistributor));
//         // TODO: uncomment
//         // zaros.registerStrategy(address(usdc), address(balancerUsdcStrategy), USDC_STRATEGY_BORROW_CAP);

//         {
//             // TODO: use correct accountNft
//             PerpsExchange perpsExchange =
//                 new PerpsExchange(address(accountNft), address(zaros), address(rewardDistributor));

//             console.log("Perps Vault: ");
//             console.log(address(perpsExchange));

//             PerpsMarket sFrxEthPerpsMarket = new PerpsMarket("sfrxETH-USD Perps Market", "SFRXETH-USD PERP",
//             ethUsdOracle, address(perpsExchange), PERPS_MAX_LEVERAGE, orderFees);

//             console.log("Perps Market: ");
//             console.log(address(sFrxEthPerpsMarket));

//             // perpsExchange.setSupportedMarket(address(sFrxEthPerpsMarket), true);
//             perpsExchange.setIsCollateralEnabled(address(zrsUsd), true);
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

//         zaros.configureCollateral(sFrxEthCollateralConfig);
//         zaros.configureCollateral(usdcCollateralConfig);

//         // TODO: configure markets

//         // Enable Zaros' general features
//         zaros.setFeatureFlagAllowAll(Constants.CREATE_ACCOUNT_FEATURE_FLAG, true);
//         zaros.setFeatureFlagAllowAll(Constants.DEPOSIT_FEATURE_FLAG, true);
//         zaros.setFeatureFlagAllowAll(Constants.WITHDRAW_FEATURE_FLAG, true);
//         zaros.setFeatureFlagAllowAll(Constants.CLAIM_FEATURE_FLAG, true);
//         zaros.setFeatureFlagAllowAll(Constants.DELEGATE_FEATURE_FLAG, true);

//         console.log("Zaros: ");
//         console.log(address(zaros));
//         console.log("Account NFT: ");
//         console.log(address(accountNft));
//         console.log("Balancer USDC Strategy: ");
//         console.log(address(balancerUsdcStrategy));
//         console.log("Reward Distributor: ");
//         console.log(address(rewardDistributor));
//     }
// }
