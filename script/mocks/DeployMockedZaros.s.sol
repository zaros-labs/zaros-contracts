// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

// Zaros dependencies
import { BaseScript } from "../Base.s.sol";
import { MockERC20 } from "../../test/mocks/MockERC20.sol";
import { MockZarosUSD } from "../../test/mocks/MockZarosUSD.sol";
import { Constants } from "@zaros/utils/Constants.sol";
import { AccountNFT } from "@zaros/account-nft/AccountNFT.sol";
import { Zaros } from "@zaros/core/Zaros.sol";
import { RewardDistributor } from "@zaros/reward-distributor/RewardDistributor.sol";
import { CollateralConfig } from "@zaros/core/storage/CollateralConfig.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract DeployMockedZaros is BaseScript {
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
        returns (MockERC20, MockERC20, MockZarosUSD, AccountNFT, Zaros, RewardDistributor, RewardDistributor)
    {
        MockERC20 sFrxEth = new MockERC20("Staked Frax Ether", "sfrxETH", 18);
        MockERC20 usdc = new MockERC20("USD Coin", "USDC", 6);
        MockZarosUSD zrsUsd = new MockZarosUSD(100_000_000e18);
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

        sFrxEth.mint(deployer, 100_000_000e18);
        usdc.mint(deployer, 100_000_000e6);

        return (sFrxEth, usdc, zrsUsd, accountNft, zaros, sFrxEthRewardDistributor, usdcRewardDistributor);
    }
}
