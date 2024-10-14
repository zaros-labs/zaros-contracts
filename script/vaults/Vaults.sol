// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { IMarketMakingEngine } from "@zaros/market-making/MarketMakingEngine.sol";
import { Vault } from "@zaros/market-making/leaves/Vault.sol";
import { Collateral } from "@zaros/market-making/leaves/Collateral.sol";
import { ZLPVault } from "@zaros/zlp/ZlpVault.sol";
import { MarginCollaterals } from "script/margin-collaterals/MarginCollaterals.sol";
import { Constants } from "@zaros/utils/Constants.sol";

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
        VaultTypes vaultType;
    }

    /// @notice Vault configurations mapped by vault id.
    mapping(uint256 vaultId => VaultConfig vaultConfig) internal vaultsConfig;

    mapping(address asset => mapping(VaultTypes vaultType => ZLPVault zlpVault)) internal zlpVaults;

    function createZLPVaults(address marketMakingEngine, address owner, uint256[2] memory vaultsIdsRange) public {
        uint256 initialVaultId = vaultsIdsRange[0];
        uint256 finalVaultlId = vaultsIdsRange[1];

        // iterate over vaultsConfig and set ZLP vaults
        for (uint256 i = initialVaultId; i <= finalVaultlId; i++) {
            address vaultAsset = vaultsConfig[i].asset;
            VaultTypes vaultType = vaultsConfig[i].vaultType;

            ZLPVault zlpVault = new ZLPVault();
            uint8 decimalOffset = Constants.SYSTEM_DECIMALS - vaultsConfig[i].decimals;
            zlpVault.initialize(marketMakingEngine, decimalOffset, owner, IERC20(vaultAsset), vaultsConfig[i].vaultId);
            zlpVaults[vaultAsset][vaultType] = zlpVault;

            vaultsConfig[i].indexToken = address(zlpVault);
        }
    }

    function setupVaultsConfig() internal {
        // Not using the margin collateral address or price feed constants as it is reset in the marginCollaterals
        // mapping
        // when MarginCollaterals::configureMarginCollaterals() is called
        address usdcAddress = marginCollaterals[USDC_MARGIN_COLLATERAL_ID].marginCollateralAddress;
        address usdcPriceAdapter = marginCollaterals[USDC_MARGIN_COLLATERAL_ID].priceAdapter;
        VaultConfig memory usdcCore = VaultConfig({
            vaultId: USDC_CORE_VAULT_ID,
            depositCap: USDC_CORE_VAULT_DEPOSIT_CAP,
            withdrawalDelay: USDC_CORE_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(0),
            asset: usdcAddress,
            creditRatio: USDC_CORE_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: USDC_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: USDC_CORE_VAULT_IS_ENABLED,
            decimals: USDC_DECIMALS,
            priceAdapter: usdcPriceAdapter,
            vaultType: VaultTypes.Core
        });
        vaultsConfig[USDC_CORE_VAULT_ID] = usdcCore;

        VaultConfig memory usdcBluechip = VaultConfig({
            vaultId: USDC_BLUECHIP_VAULT_ID,
            depositCap: USDC_BLUECHIP_VAULT_DEPOSIT_CAP,
            withdrawalDelay: USDC_BLUECHIP_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(0),
            asset: usdcAddress,
            creditRatio: USDC_BLUECHIP_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: USDC_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: USDC_BLUECHIP_VAULT_IS_ENABLED,
            decimals: USDC_DECIMALS,
            priceAdapter: usdcPriceAdapter,
            vaultType: VaultTypes.Bluechip
        });
        vaultsConfig[USDC_BLUECHIP_VAULT_ID] = usdcBluechip;

        VaultConfig memory usdcDegen = VaultConfig({
            vaultId: USDC_DEGEN_VAULT_ID,
            depositCap: USDC_DEGEN_VAULT_DEPOSIT_CAP,
            withdrawalDelay: USDC_DEGEN_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(0),
            asset: usdcAddress,
            creditRatio: USDC_DEGEN_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: USDC_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: USDC_DEGEN_VAULT_IS_ENABLED,
            decimals: USDC_DECIMALS,
            priceAdapter: usdcPriceAdapter,
            vaultType: VaultTypes.Degen
        });
        vaultsConfig[USDC_DEGEN_VAULT_ID] = usdcDegen;

        address wBtcAddress = marginCollaterals[WBTC_MARGIN_COLLATERAL_ID].marginCollateralAddress;
        address wBtcPriceAdapter = marginCollaterals[WBTC_MARGIN_COLLATERAL_ID].priceAdapter;
        VaultConfig memory wBtcCore = VaultConfig({
            vaultId: WBTC_CORE_VAULT_ID,
            depositCap: WBTC_CORE_VAULT_DEPOSIT_CAP,
            withdrawalDelay: WBTC_CORE_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(0),
            asset: wBtcAddress,
            creditRatio: WBTC_CORE_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: WBTC_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: WBTC_CORE_VAULT_IS_ENABLED,
            decimals: WBTC_DECIMALS,
            priceAdapter: wBtcPriceAdapter,
            vaultType: VaultTypes.Core
        });
        vaultsConfig[WBTC_CORE_VAULT_ID] = wBtcCore;

        VaultConfig memory wBtcBluechip = VaultConfig({
            vaultId: WBTC_BLUECHIP_VAULT_ID,
            depositCap: WBTC_BLUECHIP_VAULT_DEPOSIT_CAP,
            withdrawalDelay: WBTC_BLUECHIP_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(0),
            asset: wBtcAddress,
            creditRatio: WBTC_BLUECHIP_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: WBTC_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: WBTC_BLUECHIP_VAULT_IS_ENABLED,
            decimals: WBTC_DECIMALS,
            priceAdapter: wBtcPriceAdapter,
            vaultType: VaultTypes.Bluechip
        });
        vaultsConfig[WBTC_BLUECHIP_VAULT_ID] = wBtcBluechip;

        VaultConfig memory wBtcDegen = VaultConfig({
            vaultId: WBTC_DEGEN_VAULT_ID,
            depositCap: WBTC_DEGEN_VAULT_DEPOSIT_CAP,
            withdrawalDelay: WBTC_DEGEN_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(0),
            asset: wBtcAddress,
            creditRatio: WBTC_DEGEN_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: WBTC_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: WBTC_DEGEN_VAULT_IS_ENABLED,
            decimals: WBTC_DECIMALS,
            priceAdapter: wBtcPriceAdapter,
            vaultType: VaultTypes.Degen
        });
        vaultsConfig[WBTC_DEGEN_VAULT_ID] = wBtcDegen;

        address weEthAddress = marginCollaterals[WEETH_MARGIN_COLLATERAL_ID].marginCollateralAddress;
        address weEthPriceAdapter = marginCollaterals[WEETH_MARGIN_COLLATERAL_ID].priceAdapter;
        VaultConfig memory weEthCore = VaultConfig({
            vaultId: WEETH_CORE_VAULT_ID,
            depositCap: WEETH_CORE_VAULT_DEPOSIT_CAP,
            withdrawalDelay: WEETH_CORE_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(0),
            asset: weEthAddress,
            creditRatio: WEETH_CORE_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: WEETH_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: WEETH_CORE_VAULT_IS_ENABLED,
            decimals: WEETH_DECIMALS,
            priceAdapter: weEthPriceAdapter,
            vaultType: VaultTypes.Core
        });
        vaultsConfig[WEETH_CORE_VAULT_ID] = weEthCore;

        VaultConfig memory weEthBluechip = VaultConfig({
            vaultId: WEETH_BLUECHIP_VAULT_ID,
            depositCap: WEETH_BLUECHIP_VAULT_DEPOSIT_CAP,
            withdrawalDelay: WEETH_BLUECHIP_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(0),
            asset: weEthAddress,
            creditRatio: WEETH_BLUECHIP_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: WEETH_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: WEETH_BLUECHIP_VAULT_IS_ENABLED,
            decimals: WEETH_DECIMALS,
            priceAdapter: weEthPriceAdapter,
            vaultType: VaultTypes.Bluechip
        });
        vaultsConfig[WEETH_BLUECHIP_VAULT_ID] = weEthBluechip;

        VaultConfig memory weEthDegen = VaultConfig({
            vaultId: WEETH_DEGEN_VAULT_ID,
            depositCap: WEETH_DEGEN_VAULT_DEPOSIT_CAP,
            withdrawalDelay: WEETH_DEGEN_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(0),
            asset: weEthAddress,
            creditRatio: WEETH_DEGEN_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: WEETH_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: WEETH_DEGEN_VAULT_IS_ENABLED,
            decimals: WEETH_DECIMALS,
            priceAdapter: weEthPriceAdapter,
            vaultType: VaultTypes.Degen
        });
        vaultsConfig[WEETH_DEGEN_VAULT_ID] = weEthDegen;

        address wEthAddress = marginCollaterals[WETH_MARGIN_COLLATERAL_ID].marginCollateralAddress;
        address wEthPriceAdapter = marginCollaterals[WETH_MARGIN_COLLATERAL_ID].priceAdapter;
        VaultConfig memory wEthCore = VaultConfig({
            vaultId: WETH_CORE_VAULT_ID,
            depositCap: WETH_CORE_VAULT_DEPOSIT_CAP,
            withdrawalDelay: WETH_CORE_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(0),
            asset: wEthAddress,
            creditRatio: WETH_CORE_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: WETH_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: WETH_CORE_VAULT_IS_ENABLED,
            decimals: WETH_DECIMALS,
            priceAdapter: wEthPriceAdapter,
            vaultType: VaultTypes.Core
        });
        vaultsConfig[WETH_CORE_VAULT_ID] = wEthCore;

        VaultConfig memory wEthBluechip = VaultConfig({
            vaultId: WETH_BLUECHIP_VAULT_ID,
            depositCap: WETH_BLUECHIP_VAULT_DEPOSIT_CAP,
            withdrawalDelay: WETH_BLUECHIP_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(0),
            asset: wEthAddress,
            creditRatio: WETH_BLUECHIP_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: WETH_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: WETH_BLUECHIP_VAULT_IS_ENABLED,
            decimals: WETH_DECIMALS,
            priceAdapter: wEthPriceAdapter,
            vaultType: VaultTypes.Bluechip
        });
        vaultsConfig[WETH_BLUECHIP_VAULT_ID] = wEthBluechip;

        VaultConfig memory wEthDegen = VaultConfig({
            vaultId: WETH_DEGEN_VAULT_ID,
            depositCap: WETH_DEGEN_VAULT_DEPOSIT_CAP,
            withdrawalDelay: WETH_DEGEN_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(0),
            asset: wEthAddress,
            creditRatio: WETH_DEGEN_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: WETH_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: WETH_DEGEN_VAULT_IS_ENABLED,
            decimals: WETH_DECIMALS,
            priceAdapter: wEthPriceAdapter,
            vaultType: VaultTypes.Degen
        });
        vaultsConfig[WETH_DEGEN_VAULT_ID] = wEthDegen;

        address wStETHAddress = marginCollaterals[WSTETH_MARGIN_COLLATERAL_ID].marginCollateralAddress;
        address wStEthPriceAdapter = marginCollaterals[WSTETH_MARGIN_COLLATERAL_ID].priceAdapter;
        VaultConfig memory wStEthCore = VaultConfig({
            vaultId: WSTETH_CORE_VAULT_ID,
            depositCap: WSTETH_CORE_VAULT_DEPOSIT_CAP,
            withdrawalDelay: WSTETH_CORE_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(0),
            asset: wStETHAddress,
            creditRatio: WSTETH_CORE_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: WSTETH_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: WSTETH_CORE_VAULT_IS_ENABLED,
            decimals: WSTETH_DECIMALS,
            priceAdapter: wStEthPriceAdapter,
            vaultType: VaultTypes.Core
        });
        vaultsConfig[WSTETH_CORE_VAULT_ID] = wStEthCore;

        VaultConfig memory wStEthBluechip = VaultConfig({
            vaultId: WSTETH_BLUECHIP_VAULT_ID,
            depositCap: WSTETH_BLUECHIP_VAULT_DEPOSIT_CAP,
            withdrawalDelay: WSTETH_BLUECHIP_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(0),
            asset: wStETHAddress,
            creditRatio: WSTETH_BLUECHIP_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: WSTETH_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: WSTETH_BLUECHIP_VAULT_IS_ENABLED,
            decimals: WSTETH_DECIMALS,
            priceAdapter: wStEthPriceAdapter,
            vaultType: VaultTypes.Bluechip
        });
        vaultsConfig[WSTETH_BLUECHIP_VAULT_ID] = wStEthBluechip;

        VaultConfig memory wStEthDegen = VaultConfig({
            vaultId: WSTETH_DEGEN_VAULT_ID,
            depositCap: WSTETH_DEGEN_VAULT_DEPOSIT_CAP,
            withdrawalDelay: WSTETH_DEGEN_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(0),
            asset: wStETHAddress,
            creditRatio: WSTETH_DEGEN_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: WSTETH_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: WSTETH_DEGEN_VAULT_IS_ENABLED,
            decimals: WSTETH_DECIMALS,
            priceAdapter: wStEthPriceAdapter,
            vaultType: VaultTypes.Degen
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
