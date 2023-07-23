// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

// Zaros dependencies
import { BaseScript } from "./Base.s.sol";
import { Constants } from "@zaros/utils/Constants.sol";
import { AccountNFT } from "@zaros/account-nft/AccountNFT.sol";
import { ZarosUSD } from "@zaros/usd/ZarosUSD.sol";
import { Zaros } from "@zaros/core/Zaros.sol";
import { CollateralConfig } from "@zaros/core/storage/CollateralConfig.sol";
import { RewardDistributor } from "@zaros/reward-distributor/RewardDistributor.sol";
import { BalancerUSDCStrategy } from "@zaros/strategies/BalancerUSDCStrategy.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";

contract DeployZaros is BaseScript {
    uint80 public constant SFRXETH_ISSUANCE_RATIO = 200e18;
    uint80 public constant SFRXETH_LIQUIDATION_RATIO = 150e18;
    uint256 public constant SFRXETH_MIN_DELEGATION = 0.5e18;
    uint256 public constant SFRXETH_DEPOSIT_CAP = 100_000e18;
    uint80 public constant USDC_ISSUANCE_RATIO = 150e18;
    uint80 public constant USDC_LIQUIDATION_RATIO = 110e18;
    uint256 public constant USDC_MIN_DELEGATION = 1000e18;
    uint256 public constant USDC_DEPOSIT_CAP = 100_000_000e6;
    uint80 public constant LIQUIDATION_REWARD_RATIO = 0.05e18;
    uint128 public constant USDC_STRATEGY_BORROW_CAP = type(uint128).max;

    function run() public broadcaster {
        IERC20 sFrxEth = IERC20(vm.envAddress("SFRXETH"));
        IERC20 usdc = IERC20(vm.envAddress("USDC"));
        ZarosUSD zrsUsd = ZarosUSD(vm.envAddress("ZRSUSD"));
        AccountNFT accountNft = new AccountNFT();
        Zaros zaros = new Zaros(address(accountNft), address(zrsUsd));
        BalancerUSDCStrategy balancerUsdcStrategy =
        new BalancerUSDCStrategy(address(zaros), address(usdc), address(zrsUsd), vm.envAddress("BALANCER_VAULT"), vm.envBytes32("ZRSUSD_USDC_POOL_ID"));
        address ethUsdOracle = vm.envAddress("ETH_USD_ORACLE");
        address usdcUsdOracle = vm.envAddress("USDC_USD_ORACLE");

        zrsUsd.transferOwnership(address(zaros));
        accountNft.transferOwnership(address(zaros));

        RewardDistributor sFrxEthRewardDistributor =
            new RewardDistributor(address(zaros), address(zrsUsd), "sfrxETH Vault zrsUSD Distributor");
        RewardDistributor usdcRewardDistributor =
            new RewardDistributor(address(zaros), address(zrsUsd), "USDC Vault zrsUSD Distributor");

        zaros.registerRewardDistributor(address(sFrxEth), address(sFrxEthRewardDistributor));
        zaros.registerRewardDistributor(address(usdc), address(usdcRewardDistributor));
        zaros.registerStrategy(address(usdc), address(balancerUsdcStrategy), USDC_STRATEGY_BORROW_CAP);

        CollateralConfig.Data memory sFrxEthCollateralConfig = CollateralConfig.Data({
            depositingEnabled: true,
            issuanceRatio: SFRXETH_ISSUANCE_RATIO,
            liquidationRatio: SFRXETH_LIQUIDATION_RATIO,
            liquidationRewardRatio: LIQUIDATION_REWARD_RATIO,
            oracle: ethUsdOracle,
            tokenAddress: address(sFrxEth),
            decimals: 18,
            minDelegation: SFRXETH_MIN_DELEGATION,
            depositCap: SFRXETH_DEPOSIT_CAP
        });
        CollateralConfig.Data memory usdcCollateralConfig = CollateralConfig.Data({
            depositingEnabled: true,
            issuanceRatio: USDC_ISSUANCE_RATIO,
            liquidationRatio: USDC_ISSUANCE_RATIO,
            liquidationRewardRatio: LIQUIDATION_REWARD_RATIO,
            oracle: usdcUsdOracle,
            tokenAddress: address(usdc),
            decimals: 6,
            minDelegation: USDC_MIN_DELEGATION,
            depositCap: USDC_DEPOSIT_CAP
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
    }
}
