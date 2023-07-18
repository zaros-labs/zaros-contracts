// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

// Zaros dependencies
import { BaseScript } from "../Base.s.sol";
import { MockERC20 } from "../../test/mocks/MockERC20.sol";
import { MockZarosUSD } from "../../test/mocks/MockZarosUSD.sol";
import { AccountNFT } from "@zaros/account-nft/AccountNFT.sol";
import { Zaros } from "@zaros/core/Zaros.sol";
import { RewardDistributor } from "@zaros/reward-distributor/RewardDistributor.sol";
import { CollateralConfig } from "@zaros/core/storage/CollateralConfig.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract DeployMockedZaros is BaseScript {
    uint256 public constant sFrxEthIssuanceRatio = 200e18;
    uint256 public constant usdcIssuanceRatio = 150e18;
    uint256 public constant sFrxEthLiquidationRatio = 150e18;
    uint256 public constant usdcLiquidationRatio = 110e18;
    uint256 public constant liquidationRewardRatio = 0.05e18;

    function run() public broadcaster {
        MockERC20 sFrxEth = new MockERC20("Staked Frax Ether", "sfrxETH", 18);
        MockERC20 usdc = new MockERC20("USD Coin", "USDC", 6);
        MockZarosUSD zrsUsd = new MockZarosUSD(100_000_000e18);
        AccountNFT accountNft = new AccountNFT();
        Zaros zaros = new Zaros(address(accountNft), address(zrsUsd));
        RewardDistributor sFrxEthRewardDistributor =
            new RewardDistributor(address(zaros), address(zrsUsd), "sfrxETH Vault zrsUSD Distributor");
        RewardDistributor usdcRewardDistributor =
            new RewardDistributor(address(zaros), address(zrsUsd), "USDC Vault zrsUSD Distributor");
        zaros.registerRewardDistributor(address(sFrxEth), address(sFrxEthRewardDistributor));
        zaros.registerRewardDistributor(address(usdc), address(usdcRewardDistributor));
        CollateralConfig.Data memory collateralConfig = CollateralConfig.Data({
            depositingEnabled: true,
            issuanceRatio: sFrxEthIssuanceRatio,
            liquidationRatio: sFrxEthLiquidationRatio,
            liquidationRewardRatio: liquidationRewardRatio,
            // TODO: update this
            oracle: address(0),
            tokenAddress: address(sFrxEth),
            decimals: 18,
            minDelegation: 0.1e18
        });
        zaros.configureCollateral(collateralConfig);
        // TODO: configure markets

        sFrxEth.mint(deployer, 100_000_000e18);
        usdc.mint(deployer, 100_000_000e6);
    }
}
