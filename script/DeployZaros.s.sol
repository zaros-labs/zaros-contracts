// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

// Zaros dependencies
import { BaseScript } from "./Base.s.sol";
import { Constants } from "@zaros/utils/Constants.sol";
import { AccountNFT } from "@zaros/account-nft/AccountNFT.sol";
import { ZarosUSD } from "@zaros/usd/ZarosUSD.sol";
import { Zaros } from "@zaros/core/Zaros.sol";
import { RewardDistributor } from "@zaros/reward-distributor/RewardDistributor.sol";
import { CollateralConfig } from "@zaros/core/storage/CollateralConfig.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";

contract DeployZaros is BaseScript {
    uint256 public constant SFRXETH_ISSUANCE_RATIO = 200e18;
    uint256 public constant USDC_ISSUANCE_RATIO = 150e18;
    uint256 public constant SFRXETH_LIQUIDATION_RATIO = 150e18;
    uint256 public constant USDC_LIQUIDATION_RATIO = 110e18;
    uint256 public constant LIQUIDATION_REWARD_RATIO = 0.05e18;
    address public ethUsdOracle;
    address public usdcUsdOracle;

    function run()
        public
        broadcaster
        returns (IERC20, IERC20, ZarosUSD, AccountNFT, Zaros, RewardDistributor, RewardDistributor)
    {
        IERC20 sFrxEth = IERC20(vm.envAddress("SFRXETH"));
        IERC20 usdc = IERC20(vm.envAddress("USDC"));
        ZarosUSD zrsUsd = ZarosUSD(vm.envAddress("ZRSUSD"));
        AccountNFT accountNft = new AccountNFT();
        Zaros zaros = new Zaros(address(accountNft), address(zrsUsd));
        ethUsdOracle = vm.envAddress("ETH_USD_ORACLE");
        usdcUsdOracle = vm.envAddress("USDC_USD_ORACLE");

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
            issuanceRatio: SFRXETH_ISSUANCE_RATIO,
            liquidationRatio: SFRXETH_LIQUIDATION_RATIO,
            liquidationRewardRatio: LIQUIDATION_REWARD_RATIO,
            oracle: ethUsdOracle,
            tokenAddress: address(sFrxEth),
            decimals: 18,
            minDelegation: 0.5e18
        });
        CollateralConfig.Data memory usdcCollateralConfig = CollateralConfig.Data({
            depositingEnabled: true,
            issuanceRatio: USDC_ISSUANCE_RATIO,
            liquidationRatio: USDC_ISSUANCE_RATIO,
            liquidationRewardRatio: LIQUIDATION_REWARD_RATIO,
            oracle: usdcUsdOracle,
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

        return (sFrxEth, usdc, zrsUsd, accountNft, zaros, sFrxEthRewardDistributor, usdcRewardDistributor);
    }
}
