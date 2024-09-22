// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { IMarketMakingEngine } from "@zaros/market-making/MarketMakingEngine.sol";
import { Vault } from "@zaros/market-making/leaves/Vault.sol";
import { Collateral } from "@zaros/market-making/leaves/Collateral.sol";
import { ZLPVault } from "@zaros/zlp/ZlpVault.sol";
import { MarginCollaterals } from "script/margin-collaterals/MarginCollaterals.sol";

// Forge dependencies
import { StdCheats, StdUtils } from "forge-std/Test.sol";

// Vaults
import { UsdcCoreVault } from "./UsdcCoreVault.sol";
import { UsdcDegenVault } from "./UsdcDegenVault.sol";
import { UsdcBluechipVault } from "./UsdcBluechipVault.sol";

import { WBtcCoreVault } from "./WBtcCoreVault.sol";
import { WBtcDegenVault } from "./WBtcDegenVault.sol";
import { WBtcBluechipVault } from "./WBtcBluechipVault.sol";

import { WeEthCoreVault } from "./WeEthCoreVault.sol";
import { WeEthDegenVault } from "./WeEthDegenVault.sol";
import { WeEthBluechipVault } from "./WeEthBluechipVault.sol";

import { WEthCoreVault } from "./WEthCoreVault.sol";
import { WEthDegenVault } from "./WEthDegenVault.sol";
import { WEthBluechipVault } from "./WEthBluechipVault.sol";

import { WstEthCoreVault } from "./WstEthCoreVault.sol";
import { WstEthDegenVault } from "./WstEthDegenVault.sol";
import { WstEthBluechipVault } from "./WstEthBluechipVault.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";

enum VaultTypes {
    Core, // 0
    Degen, // 1
    Bluechip // 2

}

abstract contract Vaults is
    StdCheats,
    StdUtils,
    WeEthCoreVault,
    WeEthDegenVault,
    WeEthBluechipVault,
    UsdcCoreVault,
    UsdcDegenVault,
    UsdcBluechipVault,
    WBtcCoreVault,
    WBtcDegenVault,
    WBtcBluechipVault,
    WEthCoreVault,
    WEthDegenVault,
    WEthBluechipVault,
    WstEthCoreVault,
    WstEthDegenVault,
    WstEthBluechipVault,
    MarginCollaterals
{
    struct VaultConfig {
        uint128 vaultId;
        uint128 depositCap;
        uint128 withdrawalDelay;
        address indexToken;
        address asset;
        uint256 creditRatio;
        uint32 priceFeedHeartbeatSeconds;
        bool isEnabled;
        uint8 decimals;
        address priceAdapter;
    }

    /// @notice Vault configurations mapped by vault id.
    mapping(uint256 vaultId => VaultConfig vaultConfig) internal vaultsConfig;

    mapping(address asset => mapping(VaultTypes vaultType => ZLPVault zlpVault)) internal zlpVaults;

    function createZLPVaults(
        address marketMakingEngine,
        address owner,
        uint256[2] memory marginCollateralIdsRange
    )
        public
    {
        uint256 initialMarginCollateralId = marginCollateralIdsRange[0];
        uint256 finalMarginCollateralId = marginCollateralIdsRange[1];

        uint256 vaultTypesCount = uint256(type(VaultTypes).max) + 1;

        // iterate over collaterals
        for (uint256 i = initialMarginCollateralId; i <= finalMarginCollateralId; i++) {
            address vaultAsset = marginCollaterals[i].marginCollateralAddress;

            // iterate over vault types
            for (uint256 j = 0; j < vaultTypesCount; j++) {
                ZLPVault zlpVault = new ZLPVault();
                zlpVault.initialize(marketMakingEngine, marginCollaterals[i].tokenDecimals, owner, IERC20(vaultAsset));
                zlpVaults[vaultAsset][VaultTypes(j)] = zlpVault;
            }
        }
    }

    function setupVaultsConfig() internal {
        // Not using the margin collateral address constant as it is reset in the marginCollaterals mapping
        // when MarginCollaterals::configureMarginCollaterals() is called
        address UsdcAddress = marginCollaterals[USDC_MARGIN_COLLATERAL_ID].marginCollateralAddress;
        VaultConfig memory UsdcCore = VaultConfig({
            vaultId: USDC_CORE_VAULT_ID,
            depositCap: USDC_CORE_VAULT_DEPOSIT_CAP,
            withdrawalDelay: USDC_CORE_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(zlpVaults[UsdcAddress][VaultTypes.Core]),
            asset: UsdcAddress,
            creditRatio: USDC_CORE_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: USDC_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: USDC_CORE_VAULT_IS_ENABLED,
            decimals: USDC_DECIMALS,
            priceAdapter: USDC_PRICE_FEED
        });
        vaultsConfig[USDC_CORE_VAULT_ID] = UsdcCore;

        VaultConfig memory UsdcBluechip = VaultConfig({
            vaultId: USDC_BLUECHIP_VAULT_ID,
            depositCap: USDC_BLUECHIP_VAULT_DEPOSIT_CAP,
            withdrawalDelay: USDC_BLUECHIP_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(zlpVaults[UsdcAddress][VaultTypes.Bluechip]),
            asset: UsdcAddress,
            creditRatio: USDC_BLUECHIP_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: USDC_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: USDC_BLUECHIP_VAULT_IS_ENABLED,
            decimals: USDC_DECIMALS,
            priceAdapter: USDC_PRICE_FEED
        });
        vaultsConfig[USDC_BLUECHIP_VAULT_ID] = UsdcBluechip;

        VaultConfig memory UsdcDegen = VaultConfig({
            vaultId: USDC_DEGEN_VAULT_ID,
            depositCap: USDC_DEGEN_VAULT_DEPOSIT_CAP,
            withdrawalDelay: USDC_DEGEN_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(zlpVaults[UsdcAddress][VaultTypes.Degen]),
            asset: UsdcAddress,
            creditRatio: USDC_DEGEN_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: USDC_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: USDC_DEGEN_VAULT_IS_ENABLED,
            decimals: USDC_DECIMALS,
            priceAdapter: USDC_PRICE_FEED
        });
        vaultsConfig[USDC_DEGEN_VAULT_ID] = UsdcDegen;


        address wBtcAddress = marginCollaterals[WBTC_MARGIN_COLLATERAL_ID].marginCollateralAddress;
        VaultConfig memory wBtcCore = VaultConfig({
            vaultId: WBTC_CORE_VAULT_ID,
            depositCap: WBTC_CORE_VAULT_DEPOSIT_CAP,
            withdrawalDelay: WBTC_CORE_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(zlpVaults[wBtcAddress][VaultTypes.Core]),
            asset: wBtcAddress,
            creditRatio: WBTC_CORE_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: WBTC_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: WBTC_CORE_VAULT_IS_ENABLED,
            decimals: WBTC_DECIMALS,
            priceAdapter: WBTC_PRICE_FEED
        });
        vaultsConfig[WBTC_CORE_VAULT_ID] = wBtcCore;

        VaultConfig memory wBtcBluechip = VaultConfig({
            vaultId: WBTC_BLUECHIP_VAULT_ID,
            depositCap: WBTC_BLUECHIP_VAULT_DEPOSIT_CAP,
            withdrawalDelay: WBTC_BLUECHIP_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(zlpVaults[wBtcAddress][VaultTypes.Bluechip]),
            asset: wBtcAddress,
            creditRatio: WBTC_BLUECHIP_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: WBTC_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: WBTC_BLUECHIP_VAULT_IS_ENABLED,
            decimals: WBTC_DECIMALS,
            priceAdapter: WBTC_PRICE_FEED
        });
        vaultsConfig[WBTC_BLUECHIP_VAULT_ID] = wBtcBluechip;

        VaultConfig memory wBtcDegen = VaultConfig({
            vaultId: WBTC_DEGEN_VAULT_ID,
            depositCap: WBTC_DEGEN_VAULT_DEPOSIT_CAP,
            withdrawalDelay: WBTC_DEGEN_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(zlpVaults[wBtcAddress][VaultTypes.Degen]),
            asset: wBtcAddress,
            creditRatio: WBTC_DEGEN_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: WBTC_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: WBTC_DEGEN_VAULT_IS_ENABLED,
            decimals: WBTC_DECIMALS,
            priceAdapter: WBTC_PRICE_FEED
        });
        vaultsConfig[WBTC_DEGEN_VAULT_ID] = wBtcDegen;


        address WEETHAddress = marginCollaterals[WEETH_MARGIN_COLLATERAL_ID].marginCollateralAddress;
        VaultConfig memory weEthCore = VaultConfig({
            vaultId: WEETH_CORE_VAULT_ID,
            depositCap: WEETH_CORE_VAULT_DEPOSIT_CAP,
            withdrawalDelay: WEETH_CORE_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(zlpVaults[WEETHAddress][VaultTypes.Core]),
            asset: WEETHAddress,
            creditRatio: WEETH_CORE_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: WEETH_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: WEETH_CORE_VAULT_IS_ENABLED,
            decimals: WEETH_DECIMALS,
            priceAdapter: WEETH_PRICE_FEED
        });
        vaultsConfig[WEETH_CORE_VAULT_ID] = weEthCore;

        VaultConfig memory weEthBluechip = VaultConfig({
            vaultId: WEETH_BLUECHIP_VAULT_ID,
            depositCap: WEETH_BLUECHIP_VAULT_DEPOSIT_CAP,
            withdrawalDelay: WEETH_BLUECHIP_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(zlpVaults[WEETHAddress][VaultTypes.Bluechip]),
            asset: WEETHAddress,
            creditRatio: WEETH_BLUECHIP_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: WEETH_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: WEETH_BLUECHIP_VAULT_IS_ENABLED,
            decimals: WEETH_DECIMALS,
            priceAdapter: WEETH_PRICE_FEED
        });
        vaultsConfig[WEETH_BLUECHIP_VAULT_ID] = weEthBluechip;

        VaultConfig memory weEthDegen = VaultConfig({
            vaultId: WEETH_DEGEN_VAULT_ID,
            depositCap: WEETH_DEGEN_VAULT_DEPOSIT_CAP,
            withdrawalDelay: WEETH_DEGEN_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(zlpVaults[WEETHAddress][VaultTypes.Degen]),
            asset: WEETHAddress,
            creditRatio: WEETH_DEGEN_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: WEETH_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: WEETH_DEGEN_VAULT_IS_ENABLED,
            decimals: WEETH_DECIMALS,
            priceAdapter: WEETH_PRICE_FEED
        });
        vaultsConfig[WEETH_DEGEN_VAULT_ID] = weEthDegen;


        address WETHAddress = marginCollaterals[WETH_MARGIN_COLLATERAL_ID].marginCollateralAddress;
        VaultConfig memory wEthCore = VaultConfig({
            vaultId: WETH_CORE_VAULT_ID,
            depositCap: WETH_CORE_VAULT_DEPOSIT_CAP,
            withdrawalDelay: WETH_CORE_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(zlpVaults[WETHAddress][VaultTypes.Core]),
            asset: WETHAddress,
            creditRatio: WETH_CORE_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: WETH_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: WETH_CORE_VAULT_IS_ENABLED,
            decimals: WETH_DECIMALS,
            priceAdapter: WETH_PRICE_FEED
        });
        vaultsConfig[WETH_CORE_VAULT_ID] = wEthCore;

        VaultConfig memory wEthBluechip = VaultConfig({
            vaultId: WETH_BLUECHIP_VAULT_ID,
            depositCap: WETH_BLUECHIP_VAULT_DEPOSIT_CAP,
            withdrawalDelay: WETH_BLUECHIP_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(zlpVaults[WETHAddress][VaultTypes.Bluechip]),
            asset: WETHAddress,
            creditRatio: WETH_BLUECHIP_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: WETH_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: WETH_BLUECHIP_VAULT_IS_ENABLED,
            decimals: WETH_DECIMALS,
            priceAdapter: WETH_PRICE_FEED
        });
        vaultsConfig[WETH_BLUECHIP_VAULT_ID] = wEthBluechip;

        VaultConfig memory wEthDegen = VaultConfig({
            vaultId: WETH_DEGEN_VAULT_ID,
            depositCap: WETH_DEGEN_VAULT_DEPOSIT_CAP,
            withdrawalDelay: WETH_DEGEN_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(zlpVaults[WETHAddress][VaultTypes.Degen]),
            asset: WETHAddress,
            creditRatio: WETH_DEGEN_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: WETH_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: WETH_DEGEN_VAULT_IS_ENABLED,
            decimals: WETH_DECIMALS,
            priceAdapter: WETH_PRICE_FEED
        });
        vaultsConfig[WETH_DEGEN_VAULT_ID] = wEthDegen;


        address WStETHAddress = marginCollaterals[WSTETH_MARGIN_COLLATERAL_ID].marginCollateralAddress;
        VaultConfig memory wStEthCore = VaultConfig({
            vaultId: WSTETH_CORE_VAULT_ID,
            depositCap: WSTETH_CORE_VAULT_DEPOSIT_CAP,
            withdrawalDelay: WSTETH_CORE_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(zlpVaults[WStETHAddress][VaultTypes.Core]),
            asset: WStETHAddress,
            creditRatio: WSTETH_CORE_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: WSTETH_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: WSTETH_CORE_VAULT_IS_ENABLED,
            decimals: WSTETH_DECIMALS,
            priceAdapter: WSTETH_PRICE_FEED
        });
        vaultsConfig[WSTETH_CORE_VAULT_ID] = wStEthCore;

        VaultConfig memory wStEthBluechip = VaultConfig({
            vaultId: WSTETH_BLUECHIP_VAULT_ID,
            depositCap: WSTETH_BLUECHIP_VAULT_DEPOSIT_CAP,
            withdrawalDelay: WSTETH_BLUECHIP_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(zlpVaults[WStETHAddress][VaultTypes.Bluechip]),
            asset: WStETHAddress,
            creditRatio: WSTETH_BLUECHIP_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: WSTETH_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: WSTETH_BLUECHIP_VAULT_IS_ENABLED,
            decimals: WSTETH_DECIMALS,
            priceAdapter: WSTETH_PRICE_FEED
        });
        vaultsConfig[WSTETH_BLUECHIP_VAULT_ID] = wStEthBluechip;

        VaultConfig memory wStEthDegen = VaultConfig({
            vaultId: WSTETH_DEGEN_VAULT_ID,
            depositCap: WSTETH_DEGEN_VAULT_DEPOSIT_CAP,
            withdrawalDelay: WSTETH_DEGEN_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(zlpVaults[WStETHAddress][VaultTypes.Degen]),
            asset: WStETHAddress,
            creditRatio: WSTETH_DEGEN_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: WSTETH_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: WSTETH_DEGEN_VAULT_IS_ENABLED,
            decimals: WSTETH_DECIMALS,
            priceAdapter: WSTETH_PRICE_FEED
        });
        vaultsConfig[WSTETH_DEGEN_VAULT_ID] = wStEthDegen;
    }

    function createVaults(
        IMarketMakingEngine marketMakingEngine,
        uint256 initialVaultId,
        uint256 finalVaultId
    )
        public
    {
        for (uint256 i = initialVaultId; i <= finalVaultId; i++) {
            Collateral.Data memory collateralData = Collateral.Data(
                vaultsConfig[i].creditRatio,
                vaultsConfig[i].priceFeedHeartbeatSeconds,
                vaultsConfig[i].isEnabled,
                vaultsConfig[i].decimals,
                vaultsConfig[i].priceAdapter,
                vaultsConfig[i].asset
            );

            marketMakingEngine.createVault(
                Vault.CreateParams({
                    vaultId: vaultsConfig[i].vaultId,
                    depositCap: vaultsConfig[i].depositCap,
                    withdrawalDelay: vaultsConfig[i].withdrawalDelay,
                    indexToken: vaultsConfig[i].indexToken, // ZLP Vault shares
                    collateral: collateralData
                })
            );
        }
    }

    function getFilteredVaultsConfig(uint256[2] memory vaultsIdsRange) internal view returns (VaultConfig[] memory) {
        uint256 initialMarketId = vaultsIdsRange[0];
        uint256 finalMarketId = vaultsIdsRange[1];
        uint256 filteredVaultsLength = finalMarketId - initialMarketId + 1;

        VaultConfig[] memory filteredVaultsConfig = new VaultConfig[](filteredVaultsLength);

        uint256 nextMarketId = initialMarketId;
        for (uint256 i; i < filteredVaultsLength; i++) {
            filteredVaultsConfig[i] = vaultsConfig[nextMarketId];
            nextMarketId++;
        }

        return filteredVaultsConfig;
    }
}
