// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { IMarketMakingEngine } from "@zaros/market-making/MarketMakingEngine.sol";
import { Vault } from "@zaros/market-making/leaves/Vault.sol";
import { Collateral } from "@zaros/market-making/leaves/Collateral.sol";
import { ZlpVault } from "@zaros/zlp/ZlpVault.sol";
import { MarginCollaterals } from "script/margin-collaterals/MarginCollaterals.sol";
import { Constants } from "@zaros/utils/Constants.sol";
import { UsdTokenSwapKeeper } from "@zaros/external/chainlink/keepers/usd-token-swap-keeper/UsdTokenSwapKeeper.sol";

// Forge dependencies
import { StdCheats, StdUtils } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

// Vaults
import { UsdcCoreVault } from "script/vaults/UsdcCoreVault.sol";
import { UsdcDegenVault } from "script/vaults/UsdcDegenVault.sol";
import { UsdcBluechipVault } from "script/vaults/UsdcBluechipVault.sol";
import { UsdcPerpsEngineVault } from "script/vaults/UsdcPerpsEngineVault.sol";

import { WBtcCoreVault } from "script/vaults/WBtcCoreVault.sol";
import { WBtcDegenVault } from "script/vaults/WBtcDegenVault.sol";
import { WBtcBluechipVault } from "script/vaults/WBtcBluechipVault.sol";

import { WeEthCoreVault } from "script/vaults/WeEthCoreVault.sol";
import { WeEthDegenVault } from "script/vaults/WeEthDegenVault.sol";
import { WeEthBluechipVault } from "script/vaults/WeEthBluechipVault.sol";

import { WEthCoreVault } from "script/vaults/WEthCoreVault.sol";
import { WEthDegenVault } from "script/vaults/WEthDegenVault.sol";
import { WEthBluechipVault } from "script/vaults/WEthBluechipVault.sol";
import { WEthPerpsEngineVault } from "script/vaults/WEthPerpsEngineVault.sol";

import { WstEthCoreVault } from "script/vaults/WstEthCoreVault.sol";
import { WstEthDegenVault } from "script/vaults/WstEthDegenVault.sol";
import { WstEthBluechipVault } from "script/vaults/WstEthBluechipVault.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";
import { ERC1967Proxy } from "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

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
    UsdcPerpsEngineVault,
    WBtcCoreVault,
    WBtcDegenVault,
    WBtcBluechipVault,
    WEthCoreVault,
    WEthDegenVault,
    WEthBluechipVault,
    WEthPerpsEngineVault,
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
        uint256 depositFee;
        uint256 redeemFee;
        uint32 priceFeedHeartbeatSeconds;
        bool isEnabled;
        uint8 decimals;
        address priceAdapter;
        VaultTypes vaultType;
        string streamIdString;
        bytes32 streamId;
        address engine;
    }

    /// @notice Vault configurations mapped by vault id.
    mapping(uint256 vaultId => VaultConfig vaultConfig) internal vaultsConfig;

    mapping(address asset => mapping(VaultTypes vaultType => ZlpVault zlpVault)) internal zlpVaults;

    /// @notice Usd token swap keepers contracts mapped by asset.
    mapping(address asset => address keeper) internal usdTokenSwapKeepers;

    function createZlpVaults(address marketMakingEngine, address owner, uint256[2] memory vaultsIdsRange) public {
        uint256 initialVaultId = vaultsIdsRange[0];
        uint256 finalVaultlId = vaultsIdsRange[1];

        // iterate over vaultsConfig and set ZLP vaults
        for (uint256 i = initialVaultId; i <= finalVaultlId; i++) {
            address vaultAsset = vaultsConfig[i].asset;
            VaultTypes vaultType = vaultsConfig[i].vaultType;

            // deploy zlp vault as an upgradeable proxy
            address zlpVaultImpl = address(new ZlpVault());
            bytes memory zlpVaultInitData = abi.encodeWithSelector(
                ZlpVault.initialize.selector,
                marketMakingEngine,
                Constants.SYSTEM_DECIMALS - vaultsConfig[i].decimals,
                owner,
                IERC20(vaultAsset),
                vaultsConfig[i].vaultId
            );
            ZlpVault zlpVault = ZlpVault(address(new ERC1967Proxy(zlpVaultImpl, zlpVaultInitData)));

            zlpVaults[vaultAsset][vaultType] = zlpVault;
            vaultsConfig[i].indexToken = address(zlpVault);

            if (usdTokenSwapKeepers[vaultAsset] == address(0)) {
                deployUsdTokenSwapKeeper(owner, marketMakingEngine, vaultAsset, vaultsConfig[i].streamIdString);
            }
        }
    }

    struct VaultsByChainParams {
        address asset;
        address priceAdapter;
        address engine;
    }

    mapping(uint256 chainId => VaultsByChainParams) vaultsByChain;

    function setupVaultsConfig(bool isTest) internal {
        vaultsByChain[421_614].asset = USDC_ARB_SEPOLIA_CORE_VAULT_ASSET;
        vaultsByChain[421_614].priceAdapter = USDC_ARB_SEPOLIA_CORE_VAULT_PRICE_ADAPTER;
        vaultsByChain[421_614].engine = USDC_ARB_SEPOLIA_CORE_VAULT_ENGINE;

        vaultsByChain[10_143].asset = USDC_MONAD_TESTNET_CORE_VAULT_ASSET;
        vaultsByChain[10_143].priceAdapter = USDC_MONAD_TESTNET_CORE_VAULT_PRICE_ADAPTER;
        vaultsByChain[10_143].engine = USDC_MONAD_TESTNET_CORE_VAULT_ENGINE;

        vaultsByChain[31_337].asset = marginCollaterals[USDC_MARGIN_COLLATERAL_ID].marginCollateralAddress;
        vaultsByChain[31_337].priceAdapter = marginCollaterals[USDC_MARGIN_COLLATERAL_ID].priceAdapter;
        vaultsByChain[31_337].engine = address(0);

        VaultConfig memory usdcCore = VaultConfig({
            vaultId: USDC_CORE_VAULT_ID,
            depositCap: USDC_CORE_VAULT_DEPOSIT_CAP,
            withdrawalDelay: USDC_CORE_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(0),
            asset: vaultsByChain[block.chainid].asset,
            creditRatio: USDC_CORE_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: USDC_ARB_SEPOLIA_CHAINLINK_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: USDC_CORE_VAULT_IS_ENABLED,
            decimals: USDC_DECIMALS,
            priceAdapter: vaultsByChain[block.chainid].priceAdapter,
            vaultType: VaultTypes.Core,
            streamIdString: USDC_USD_ARB_SEPOLIA_STREAM_ID_STRING,
            streamId: USDC_USD_ARB_SEPOLIA_STREAM_ID,
            depositFee: USDC_CORE_VAULT_DEPOSIT_FEE,
            redeemFee: USDC_CORE_VAULT_REDEEM_FEE,
            engine: vaultsByChain[block.chainid].engine
        });
        vaultsConfig[USDC_CORE_VAULT_ID] = usdcCore;

        vaultsByChain[421_614].asset = USDC_ARB_SEPOLIA_BLUECHIP_VAULT_ASSET;
        vaultsByChain[421_614].priceAdapter = USDC_ARB_SEPOLIA_BLUECHIP_VAULT_PRICE_ADAPTER;
        vaultsByChain[421_614].engine = USDC_ARB_SEPOLIA_BLUECHIP_VAULT_ENGINE;

        vaultsByChain[10_143].asset = USDC_MONAD_TESTNET_BLUECHIP_VAULT_ASSET;
        vaultsByChain[10_143].priceAdapter = USDC_MONAD_TESTNET_BLUECHIP_VAULT_PRICE_ADAPTER;
        vaultsByChain[10_143].engine = USDC_MONAD_TESTNET_BLUECHIP_VAULT_ENGINE;

        VaultConfig memory usdcBluechip = VaultConfig({
            vaultId: USDC_BLUECHIP_VAULT_ID,
            depositCap: USDC_BLUECHIP_VAULT_DEPOSIT_CAP,
            withdrawalDelay: USDC_BLUECHIP_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(0),
            asset: vaultsByChain[block.chainid].asset,
            creditRatio: USDC_BLUECHIP_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: USDC_ARB_SEPOLIA_CHAINLINK_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: USDC_BLUECHIP_VAULT_IS_ENABLED,
            decimals: USDC_DECIMALS,
            priceAdapter: vaultsByChain[block.chainid].priceAdapter,
            vaultType: VaultTypes.Bluechip,
            streamIdString: USDC_USD_ARB_SEPOLIA_STREAM_ID_STRING,
            streamId: USDC_USD_ARB_SEPOLIA_STREAM_ID,
            depositFee: USDC_BLUECHIP_VAULT_DEPOSIT_FEE,
            redeemFee: USDC_BLUECHIP_VAULT_REDEEM_FEE,
            engine: vaultsByChain[block.chainid].engine
        });
        vaultsConfig[USDC_BLUECHIP_VAULT_ID] = usdcBluechip;

        vaultsByChain[421_614].asset = USDC_ARB_SEPOLIA_DEGEN_VAULT_ASSET;
        vaultsByChain[421_614].priceAdapter = USDC_ARB_SEPOLIA_DEGEN_VAULT_PRICE_ADAPTER;
        vaultsByChain[421_614].engine = USDC_ARB_SEPOLIA_DEGEN_VAULT_ENGINE;

        vaultsByChain[10_143].asset = USDC_MONAD_TESTNET_DEGEN_VAULT_ASSET;
        vaultsByChain[10_143].priceAdapter = USDC_MONAD_TESTNET_DEGEN_VAULT_PRICE_ADAPTER;
        vaultsByChain[10_143].engine = USDC_MONAD_TESTNET_DEGEN_VAULT_ENGINE;

        VaultConfig memory usdcDegen = VaultConfig({
            vaultId: USDC_DEGEN_VAULT_ID,
            depositCap: USDC_DEGEN_VAULT_DEPOSIT_CAP,
            withdrawalDelay: USDC_DEGEN_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(0),
            asset: vaultsByChain[block.chainid].asset,
            creditRatio: USDC_DEGEN_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: USDC_ARB_SEPOLIA_CHAINLINK_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: USDC_DEGEN_VAULT_IS_ENABLED,
            decimals: USDC_DECIMALS,
            priceAdapter: vaultsByChain[block.chainid].priceAdapter,
            vaultType: VaultTypes.Degen,
            streamIdString: USDC_USD_ARB_SEPOLIA_STREAM_ID_STRING,
            streamId: USDC_USD_ARB_SEPOLIA_STREAM_ID,
            depositFee: USDC_DEGEN_VAULT_DEPOSIT_FEE,
            redeemFee: USDC_DEGEN_VAULT_REDEEM_FEE,
            engine: vaultsByChain[block.chainid].engine
        });
        vaultsConfig[USDC_DEGEN_VAULT_ID] = usdcDegen;

        vaultsByChain[421_614].asset = WBTC_ARB_SEPOLIA_CORE_VAULT_ASSET;
        vaultsByChain[421_614].priceAdapter = WBTC_ARB_SEPOLIA_CORE_VAULT_PRICE_ADAPTER;
        vaultsByChain[421_614].engine = WBTC_ARB_SEPOLIA_CORE_VAULT_ENGINE;

        vaultsByChain[10_143].asset = WBTC_MONAD_TESTNET_CORE_VAULT_ASSET;
        vaultsByChain[10_143].priceAdapter = WBTC_MONAD_TESTNET_CORE_VAULT_PRICE_ADAPTER;
        vaultsByChain[10_143].engine = WBTC_MONAD_TESTNET_CORE_VAULT_ENGINE;

        vaultsByChain[31_337].asset = marginCollaterals[WBTC_MARGIN_COLLATERAL_ID].marginCollateralAddress;
        vaultsByChain[31_337].priceAdapter = marginCollaterals[WBTC_MARGIN_COLLATERAL_ID].priceAdapter;
        vaultsByChain[31_337].engine = address(0);

        VaultConfig memory wBtcCore = VaultConfig({
            vaultId: WBTC_CORE_VAULT_ID,
            depositCap: WBTC_CORE_VAULT_DEPOSIT_CAP,
            withdrawalDelay: WBTC_CORE_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(0),
            asset: vaultsByChain[block.chainid].asset,
            creditRatio: WBTC_CORE_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: WBTC_ARB_SEPOLIA_CHAINLINK_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: WBTC_CORE_VAULT_IS_ENABLED,
            decimals: WBTC_DECIMALS,
            priceAdapter: vaultsByChain[block.chainid].priceAdapter,
            vaultType: VaultTypes.Core,
            streamIdString: WBTC_USD_ARB_SEPOLIA_STREAM_ID_STRING,
            streamId: WBTC_USD_ARB_SEPOLIA_STREAM_ID,
            depositFee: WBTC_CORE_VAULT_DEPOSIT_FEE,
            redeemFee: WBTC_CORE_VAULT_REDEEM_FEE,
            engine: vaultsByChain[block.chainid].engine
        });
        vaultsConfig[WBTC_CORE_VAULT_ID] = wBtcCore;

        vaultsByChain[421_614].asset = WBTC_ARB_SEPOLIA_BLUECHIP_VAULT_ASSET;
        vaultsByChain[421_614].priceAdapter = WBTC_ARB_SEPOLIA_BLUECHIP_VAULT_PRICE_ADAPTER;
        vaultsByChain[421_614].engine = WBTC_ARB_SEPOLIA_BLUECHIP_VAULT_ENGINE;

        vaultsByChain[10_143].asset = WBTC_MONAD_TESTNET_BLUECHIP_VAULT_ASSET;
        vaultsByChain[10_143].priceAdapter = WBTC_MONAD_TESTNET_BLUECHIP_VAULT_PRICE_ADAPTER;
        vaultsByChain[10_143].engine = WBTC_MONAD_TESTNET_BLUECHIP_VAULT_ENGINE;

        VaultConfig memory wBtcBluechip = VaultConfig({
            vaultId: WBTC_BLUECHIP_VAULT_ID,
            depositCap: WBTC_BLUECHIP_VAULT_DEPOSIT_CAP,
            withdrawalDelay: WBTC_BLUECHIP_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(0),
            asset: vaultsByChain[block.chainid].asset,
            creditRatio: WBTC_BLUECHIP_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: WBTC_ARB_SEPOLIA_CHAINLINK_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: WBTC_BLUECHIP_VAULT_IS_ENABLED,
            decimals: WBTC_DECIMALS,
            priceAdapter: vaultsByChain[block.chainid].priceAdapter,
            vaultType: VaultTypes.Bluechip,
            streamIdString: WBTC_USD_ARB_SEPOLIA_STREAM_ID_STRING,
            streamId: WBTC_USD_ARB_SEPOLIA_STREAM_ID,
            depositFee: WBTC_BLUECHIP_VAULT_DEPOSIT_FEE,
            redeemFee: WBTC_BLUECHIP_VAULT_REDEEM_FEE,
            engine: vaultsByChain[block.chainid].engine
        });
        vaultsConfig[WBTC_BLUECHIP_VAULT_ID] = wBtcBluechip;

        vaultsByChain[421_614].asset = WBTC_ARB_SEPOLIA_DEGEN_VAULT_ASSET;
        vaultsByChain[421_614].priceAdapter = WBTC_ARB_SEPOLIA_DEGEN_VAULT_PRICE_ADAPTER;
        vaultsByChain[421_614].engine = WBTC_ARB_SEPOLIA_DEGEN_VAULT_ENGINE;

        vaultsByChain[10_143].asset = WBTC_MONAD_TESTNET_DEGEN_VAULT_ASSET;
        vaultsByChain[10_143].priceAdapter = WBTC_MONAD_TESTNET_DEGEN_VAULT_PRICE_ADAPTER;
        vaultsByChain[10_143].engine = WBTC_MONAD_TESTNET_DEGEN_VAULT_ENGINE;

        VaultConfig memory wBtcDegen = VaultConfig({
            vaultId: WBTC_DEGEN_VAULT_ID,
            depositCap: WBTC_DEGEN_VAULT_DEPOSIT_CAP,
            withdrawalDelay: WBTC_DEGEN_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(0),
            asset: vaultsByChain[block.chainid].asset,
            creditRatio: WBTC_DEGEN_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: WBTC_ARB_SEPOLIA_CHAINLINK_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: WBTC_DEGEN_VAULT_IS_ENABLED,
            decimals: WBTC_DECIMALS,
            priceAdapter: vaultsByChain[block.chainid].priceAdapter,
            vaultType: VaultTypes.Degen,
            streamIdString: WBTC_USD_ARB_SEPOLIA_STREAM_ID_STRING,
            streamId: WBTC_USD_ARB_SEPOLIA_STREAM_ID,
            depositFee: WBTC_DEGEN_VAULT_DEPOSIT_FEE,
            redeemFee: WBTC_DEGEN_VAULT_REDEEM_FEE,
            engine: vaultsByChain[block.chainid].engine
        });
        vaultsConfig[WBTC_DEGEN_VAULT_ID] = wBtcDegen;

        vaultsByChain[421_614].asset = WEETH_ARB_SEPOLIA_CORE_VAULT_ASSET;
        vaultsByChain[421_614].priceAdapter = WEETH_ARB_SEPOLIA_CORE_VAULT_PRICE_ADAPTER;
        vaultsByChain[421_614].engine = WEETH_ARB_SEPOLIA_CORE_VAULT_ENGINE;

        vaultsByChain[10_143].asset = WEETH_MONAD_TESTNET_CORE_VAULT_ASSET;
        vaultsByChain[10_143].priceAdapter = WEETH_MONAD_TESTNET_CORE_VAULT_PRICE_ADAPTER;
        vaultsByChain[10_143].engine = WEETH_MONAD_TESTNET_CORE_VAULT_ENGINE;

        vaultsByChain[31_337].asset = marginCollaterals[WEETH_MARGIN_COLLATERAL_ID].marginCollateralAddress;
        vaultsByChain[31_337].priceAdapter = marginCollaterals[WEETH_MARGIN_COLLATERAL_ID].priceAdapter;
        vaultsByChain[31_337].engine = address(0);

        VaultConfig memory weEthCore = VaultConfig({
            vaultId: WEETH_CORE_VAULT_ID,
            depositCap: WEETH_CORE_VAULT_DEPOSIT_CAP,
            withdrawalDelay: WEETH_CORE_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(0),
            asset: vaultsByChain[block.chainid].asset,
            creditRatio: WEETH_CORE_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: WEETH_ARB_SEPOLIA_CHAINLINK_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: WEETH_CORE_VAULT_IS_ENABLED,
            decimals: WEETH_DECIMALS,
            priceAdapter: vaultsByChain[block.chainid].priceAdapter,
            vaultType: VaultTypes.Core,
            streamIdString: WEETH_USD_ARB_SEPOLIA_STREAM_ID_STRING,
            streamId: WEETH_USD_ARB_SEPOLIA_STREAM_ID,
            depositFee: WEETH_CORE_VAULT_DEPOSIT_FEE,
            redeemFee: WEETH_CORE_VAULT_REDEEM_FEE,
            engine: vaultsByChain[block.chainid].engine
        });
        vaultsConfig[WEETH_CORE_VAULT_ID] = weEthCore;

        vaultsByChain[421_614].asset = WEETH_ARB_SEPOLIA_BLUECHIP_VAULT_ASSET;
        vaultsByChain[421_614].priceAdapter = WEETH_ARB_SEPOLIA_BLUECHIP_VAULT_PRICE_ADAPTER;
        vaultsByChain[421_614].engine = WEETH_ARB_SEPOLIA_BLUECHIP_VAULT_ENGINE;

        vaultsByChain[10_143].asset = WEETH_MONAD_TESTNET_BLUECHIP_VAULT_ASSET;
        vaultsByChain[10_143].priceAdapter = WEETH_MONAD_TESTNET_BLUECHIP_VAULT_PRICE_ADAPTER;
        vaultsByChain[10_143].engine = WEETH_MONAD_TESTNET_BLUECHIP_VAULT_ENGINE;

        VaultConfig memory weEthBluechip = VaultConfig({
            vaultId: WEETH_BLUECHIP_VAULT_ID,
            depositCap: WEETH_BLUECHIP_VAULT_DEPOSIT_CAP,
            withdrawalDelay: WEETH_BLUECHIP_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(0),
            asset: vaultsByChain[block.chainid].asset,
            creditRatio: WEETH_BLUECHIP_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: WEETH_ARB_SEPOLIA_CHAINLINK_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: WEETH_BLUECHIP_VAULT_IS_ENABLED,
            decimals: WEETH_DECIMALS,
            priceAdapter: vaultsByChain[block.chainid].priceAdapter,
            vaultType: VaultTypes.Bluechip,
            streamIdString: WEETH_USD_ARB_SEPOLIA_STREAM_ID_STRING,
            streamId: WEETH_USD_ARB_SEPOLIA_STREAM_ID,
            depositFee: WEETH_BLUECHIP_VAULT_DEPOSIT_FEE,
            redeemFee: WEETH_BLUECHIP_VAULT_REDEEM_FEE,
            engine: vaultsByChain[block.chainid].engine
        });
        vaultsConfig[WEETH_BLUECHIP_VAULT_ID] = weEthBluechip;

        vaultsByChain[421_614].asset = WEETH_ARB_SEPOLIA_DEGEN_VAULT_ASSET;
        vaultsByChain[421_614].priceAdapter = WEETH_ARB_SEPOLIA_DEGEN_VAULT_PRICE_ADAPTER;
        vaultsByChain[421_614].engine = WEETH_ARB_SEPOLIA_DEGEN_VAULT_ENGINE;

        vaultsByChain[10_143].asset = WEETH_MONAD_TESTNET_DEGEN_VAULT_ASSET;
        vaultsByChain[10_143].priceAdapter = WEETH_MONAD_TESTNET_DEGEN_VAULT_PRICE_ADAPTER;
        vaultsByChain[10_143].engine = WEETH_MONAD_TESTNET_DEGEN_VAULT_ENGINE;

        VaultConfig memory weEthDegen = VaultConfig({
            vaultId: WEETH_DEGEN_VAULT_ID,
            depositCap: WEETH_DEGEN_VAULT_DEPOSIT_CAP,
            withdrawalDelay: WEETH_DEGEN_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(0),
            asset: vaultsByChain[block.chainid].asset,
            creditRatio: WEETH_DEGEN_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: WEETH_ARB_SEPOLIA_CHAINLINK_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: WEETH_DEGEN_VAULT_IS_ENABLED,
            decimals: WEETH_DECIMALS,
            priceAdapter: vaultsByChain[block.chainid].priceAdapter,
            vaultType: VaultTypes.Degen,
            streamIdString: WEETH_USD_ARB_SEPOLIA_STREAM_ID_STRING,
            streamId: WEETH_USD_ARB_SEPOLIA_STREAM_ID,
            depositFee: WEETH_DEGEN_VAULT_DEPOSIT_FEE,
            redeemFee: WEETH_DEGEN_VAULT_REDEEM_FEE,
            engine: vaultsByChain[block.chainid].engine
        });
        vaultsConfig[WEETH_DEGEN_VAULT_ID] = weEthDegen;

        vaultsByChain[421_614].asset = WETH_ARB_SEPOLIA_CORE_VAULT_ASSET;
        vaultsByChain[421_614].priceAdapter = WETH_ARB_SEPOLIA_CORE_VAULT_PRICE_ADAPTER;
        vaultsByChain[421_614].engine = WETH_ARB_SEPOLIA_CORE_VAULT_ENGINE;

        vaultsByChain[10_143].asset = WETH_MONAD_TESTNET_CORE_VAULT_ASSET;
        vaultsByChain[10_143].priceAdapter = WETH_MONAD_TESTNET_CORE_VAULT_PRICE_ADAPTER;
        vaultsByChain[10_143].engine = WETH_MONAD_TESTNET_CORE_VAULT_ENGINE;

        vaultsByChain[31_337].asset = marginCollaterals[WETH_MARGIN_COLLATERAL_ID].marginCollateralAddress;
        vaultsByChain[31_337].priceAdapter = marginCollaterals[WETH_MARGIN_COLLATERAL_ID].priceAdapter;
        vaultsByChain[31_337].engine = address(0);

        VaultConfig memory wEthCore = VaultConfig({
            vaultId: WETH_CORE_VAULT_ID,
            depositCap: WETH_CORE_VAULT_DEPOSIT_CAP,
            withdrawalDelay: WETH_CORE_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(0),
            asset: vaultsByChain[block.chainid].asset,
            creditRatio: WETH_CORE_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: WETH_ARB_SEPOLIA_CHAINLINK_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: WETH_CORE_VAULT_IS_ENABLED,
            decimals: WETH_DECIMALS,
            priceAdapter: vaultsByChain[block.chainid].priceAdapter,
            vaultType: VaultTypes.Core,
            streamIdString: WETH_USD_ARB_SEPOLIA_STREAM_ID_STRING,
            streamId: WETH_USD_ARB_SEPOLIA_STREAM_ID,
            depositFee: WETH_CORE_VAULT_DEPOSIT_FEE,
            redeemFee: WETH_CORE_VAULT_REDEEM_FEE,
            engine: vaultsByChain[block.chainid].engine
        });
        vaultsConfig[WETH_CORE_VAULT_ID] = wEthCore;

        vaultsByChain[421_614].asset = WETH_ARB_SEPOLIA_BLUECHIP_VAULT_ASSET;
        vaultsByChain[421_614].priceAdapter = WETH_ARB_SEPOLIA_BLUECHIP_VAULT_PRICE_ADAPTER;
        vaultsByChain[421_614].engine = WETH_ARB_SEPOLIA_BLUECHIP_VAULT_ENGINE;

        vaultsByChain[10_143].asset = WETH_MONAD_TESTNET_BLUECHIP_VAULT_ASSET;
        vaultsByChain[10_143].priceAdapter = WETH_MONAD_TESTNET_BLUECHIP_VAULT_PRICE_ADAPTER;
        vaultsByChain[10_143].engine = WETH_MONAD_TESTNET_BLUECHIP_VAULT_ENGINE;

        VaultConfig memory wEthBluechip = VaultConfig({
            vaultId: WETH_BLUECHIP_VAULT_ID,
            depositCap: WETH_BLUECHIP_VAULT_DEPOSIT_CAP,
            withdrawalDelay: WETH_BLUECHIP_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(0),
            asset: vaultsByChain[block.chainid].asset,
            creditRatio: WETH_BLUECHIP_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: WETH_ARB_SEPOLIA_CHAINLINK_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: WETH_BLUECHIP_VAULT_IS_ENABLED,
            decimals: WETH_DECIMALS,
            priceAdapter: vaultsByChain[block.chainid].priceAdapter,
            vaultType: VaultTypes.Bluechip,
            streamIdString: WETH_USD_ARB_SEPOLIA_STREAM_ID_STRING,
            streamId: WETH_USD_ARB_SEPOLIA_STREAM_ID,
            depositFee: WETH_BLUECHIP_VAULT_DEPOSIT_FEE,
            redeemFee: WETH_BLUECHIP_VAULT_REDEEM_FEE,
            engine: vaultsByChain[block.chainid].engine
        });
        vaultsConfig[WETH_BLUECHIP_VAULT_ID] = wEthBluechip;

        vaultsByChain[421_614].asset = WETH_ARB_SEPOLIA_DEGEN_VAULT_ASSET;
        vaultsByChain[421_614].priceAdapter = WETH_ARB_SEPOLIA_DEGEN_VAULT_PRICE_ADAPTER;
        vaultsByChain[421_614].engine = WETH_ARB_SEPOLIA_DEGEN_VAULT_ENGINE;

        vaultsByChain[10_143].asset = WETH_MONAD_TESTNET_DEGEN_VAULT_ASSET;
        vaultsByChain[10_143].priceAdapter = WETH_MONAD_TESTNET_DEGEN_VAULT_PRICE_ADAPTER;
        vaultsByChain[10_143].engine = WETH_MONAD_TESTNET_DEGEN_VAULT_ENGINE;

        VaultConfig memory wEthDegen = VaultConfig({
            vaultId: WETH_DEGEN_VAULT_ID,
            depositCap: WETH_DEGEN_VAULT_DEPOSIT_CAP,
            withdrawalDelay: WETH_DEGEN_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(0),
            asset: vaultsByChain[block.chainid].asset,
            creditRatio: WETH_DEGEN_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: WETH_ARB_SEPOLIA_CHAINLINK_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: WETH_DEGEN_VAULT_IS_ENABLED,
            decimals: WETH_DECIMALS,
            priceAdapter: vaultsByChain[block.chainid].priceAdapter,
            vaultType: VaultTypes.Degen,
            streamIdString: WETH_USD_ARB_SEPOLIA_STREAM_ID_STRING,
            streamId: WETH_USD_ARB_SEPOLIA_STREAM_ID,
            depositFee: WETH_DEGEN_VAULT_DEPOSIT_FEE,
            redeemFee: WETH_DEGEN_VAULT_REDEEM_FEE,
            engine: vaultsByChain[block.chainid].engine
        });
        vaultsConfig[WETH_DEGEN_VAULT_ID] = wEthDegen;

        vaultsByChain[421_614].asset = WSTETH_ARB_SEPOLIA_CORE_VAULT_ASSET;
        vaultsByChain[421_614].priceAdapter = WSTETH_ARB_SEPOLIA_CORE_VAULT_PRICE_ADAPTER;
        vaultsByChain[421_614].engine = WSTETH_ARB_SEPOLIA_CORE_VAULT_ENGINE;

        vaultsByChain[10_143].asset = WSTETH_MONAD_TESTNET_CORE_VAULT_ASSET;
        vaultsByChain[10_143].priceAdapter = WSTETH_MONAD_TESTNET_CORE_VAULT_PRICE_ADAPTER;
        vaultsByChain[10_143].engine = WSTETH_MONAD_TESTNET_CORE_VAULT_ENGINE;

        vaultsByChain[31_337].asset = marginCollaterals[WSTETH_MARGIN_COLLATERAL_ID].marginCollateralAddress;
        vaultsByChain[31_337].priceAdapter = marginCollaterals[WSTETH_MARGIN_COLLATERAL_ID].priceAdapter;
        vaultsByChain[31_337].engine = address(0);

        VaultConfig memory wStEthCore = VaultConfig({
            vaultId: WSTETH_CORE_VAULT_ID,
            depositCap: WSTETH_CORE_VAULT_DEPOSIT_CAP,
            withdrawalDelay: WSTETH_CORE_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(0),
            asset: vaultsByChain[block.chainid].asset,
            creditRatio: WSTETH_CORE_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: WSTETH_ARB_SEPOLIA_CHAINLINK_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: WSTETH_CORE_VAULT_IS_ENABLED,
            decimals: WSTETH_DECIMALS,
            priceAdapter: vaultsByChain[block.chainid].priceAdapter,
            vaultType: VaultTypes.Core,
            streamIdString: WSTETH_USD_ARB_SEPOLIA_STREAM_ID_STRING,
            streamId: WSTETH_USD_ARB_SEPOLIA_STREAM_ID,
            depositFee: WSTETH_CORE_VAULT_DEPOSIT_FEE,
            redeemFee: WSTETH_CORE_VAULT_REDEEM_FEE,
            engine: vaultsByChain[block.chainid].engine
        });
        vaultsConfig[WSTETH_CORE_VAULT_ID] = wStEthCore;

        vaultsByChain[421_614].asset = WSTETH_ARB_SEPOLIA_BLUECHIP_VAULT_ASSET;
        vaultsByChain[421_614].priceAdapter = WSTETH_ARB_SEPOLIA_BLUECHIP_VAULT_PRICE_ADAPTER;
        vaultsByChain[421_614].engine = WSTETH_ARB_SEPOLIA_BLUECHIP_VAULT_ENGINE;

        vaultsByChain[10_143].asset = WSTETH_MONAD_TESTNET_BLUECHIP_VAULT_ASSET;
        vaultsByChain[10_143].priceAdapter = WSTETH_MONAD_TESTNET_BLUECHIP_VAULT_PRICE_ADAPTER;
        vaultsByChain[10_143].engine = WSTETH_MONAD_TESTNET_BLUECHIP_VAULT_ENGINE;

        VaultConfig memory wStEthBluechip = VaultConfig({
            vaultId: WSTETH_BLUECHIP_VAULT_ID,
            depositCap: WSTETH_BLUECHIP_VAULT_DEPOSIT_CAP,
            withdrawalDelay: WSTETH_BLUECHIP_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(0),
            asset: vaultsByChain[block.chainid].asset,
            creditRatio: WSTETH_BLUECHIP_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: WSTETH_ARB_SEPOLIA_CHAINLINK_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: WSTETH_BLUECHIP_VAULT_IS_ENABLED,
            decimals: WSTETH_DECIMALS,
            priceAdapter: vaultsByChain[block.chainid].priceAdapter,
            vaultType: VaultTypes.Bluechip,
            streamIdString: WSTETH_USD_ARB_SEPOLIA_STREAM_ID_STRING,
            streamId: WSTETH_USD_ARB_SEPOLIA_STREAM_ID,
            depositFee: WSTETH_BLUECHIP_VAULT_DEPOSIT_FEE,
            redeemFee: WSTETH_BLUECHIP_VAULT_REDEEM_FEE,
            engine: vaultsByChain[block.chainid].engine
        });
        vaultsConfig[WSTETH_BLUECHIP_VAULT_ID] = wStEthBluechip;

        vaultsByChain[421_614].asset = WSTETH_ARB_SEPOLIA_DEGEN_VAULT_ASSET;
        vaultsByChain[421_614].priceAdapter = WSTETH_ARB_SEPOLIA_DEGEN_VAULT_PRICE_ADAPTER;
        vaultsByChain[421_614].engine = WSTETH_ARB_SEPOLIA_DEGEN_VAULT_ENGINE;

        vaultsByChain[10_143].asset = WSTETH_MONAD_TESTNET_DEGEN_VAULT_ASSET;
        vaultsByChain[10_143].priceAdapter = WSTETH_MONAD_TESTNET_DEGEN_VAULT_PRICE_ADAPTER;
        vaultsByChain[10_143].engine = WSTETH_MONAD_TESTNET_DEGEN_VAULT_ENGINE;

        VaultConfig memory wStEthDegen = VaultConfig({
            vaultId: WSTETH_DEGEN_VAULT_ID,
            depositCap: WSTETH_DEGEN_VAULT_DEPOSIT_CAP,
            withdrawalDelay: WSTETH_DEGEN_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(0),
            asset: vaultsByChain[block.chainid].asset,
            creditRatio: WSTETH_DEGEN_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: WSTETH_ARB_SEPOLIA_CHAINLINK_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: WSTETH_DEGEN_VAULT_IS_ENABLED,
            decimals: WSTETH_DECIMALS,
            priceAdapter: vaultsByChain[block.chainid].priceAdapter,
            vaultType: VaultTypes.Degen,
            streamIdString: WSTETH_USD_ARB_SEPOLIA_STREAM_ID_STRING,
            streamId: WSTETH_USD_ARB_SEPOLIA_STREAM_ID,
            depositFee: WSTETH_DEGEN_VAULT_DEPOSIT_FEE,
            redeemFee: WSTETH_DEGEN_VAULT_REDEEM_FEE,
            engine: vaultsByChain[block.chainid].engine
        });
        vaultsConfig[WSTETH_DEGEN_VAULT_ID] = wStEthDegen;

        vaultsByChain[421_614].asset = USDC_ARB_SEPOLIA_PERPS_ENGINE_VAULT_ASSET;
        vaultsByChain[421_614].priceAdapter = USDC_ARB_SEPOLIA_PERPS_ENGINE_VAULT_PRICE_ADAPTER;
        vaultsByChain[421_614].engine = USDC_ARB_SEPOLIA_PERPS_ENGINE_VAULT_ENGINE;

        vaultsByChain[10_143].asset = USDC_MONAD_TESTNET_PERPS_ENGINE_VAULT_ASSET;
        vaultsByChain[10_143].priceAdapter = USDC_MONAD_TESTNET_PERPS_ENGINE_VAULT_PRICE_ADAPTER;
        vaultsByChain[10_143].engine = USDC_MONAD_TESTNET_PERPS_ENGINE_VAULT_ENGINE;

        vaultsByChain[31_337].asset = marginCollaterals[USDC_MARGIN_COLLATERAL_ID].marginCollateralAddress;
        vaultsByChain[31_337].priceAdapter = marginCollaterals[USDC_MARGIN_COLLATERAL_ID].priceAdapter;
        vaultsByChain[31_337].engine = address(0);

        VaultConfig memory usdcPerpsEngine = VaultConfig({
            vaultId: USDC_PERPS_ENGINE_VAULT_ID,
            depositCap: USDC_PERPS_ENGINE_VAULT_DEPOSIT_CAP,
            withdrawalDelay: USDC_PERPS_ENGINE_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(0),
            asset: vaultsByChain[block.chainid].asset,
            creditRatio: USDC_PERPS_ENGINE_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: USDC_ARB_SEPOLIA_CHAINLINK_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: USDC_PERPS_ENGINE_VAULT_IS_ENABLED,
            decimals: USDC_DECIMALS,
            priceAdapter: vaultsByChain[block.chainid].priceAdapter,
            vaultType: VaultTypes.Core,
            streamIdString: USDC_USD_ARB_SEPOLIA_STREAM_ID_STRING,
            streamId: USDC_USD_ARB_SEPOLIA_STREAM_ID,
            depositFee: USDC_PERPS_ENGINE_VAULT_DEPOSIT_FEE,
            redeemFee: USDC_PERPS_ENGINE_VAULT_REDEEM_FEE,
            engine: vaultsByChain[block.chainid].engine
        });
        vaultsConfig[USDC_PERPS_ENGINE_VAULT_ID] = usdcPerpsEngine;

        vaultsByChain[421_614].asset = WETH_ARB_SEPOLIA_PERPS_ENGINE_VAULT_ASSET;
        vaultsByChain[421_614].priceAdapter = WETH_ARB_SEPOLIA_PERPS_ENGINE_VAULT_PRICE_ADAPTER;
        vaultsByChain[421_614].engine = WETH_ARB_SEPOLIA_PERPS_ENGINE_VAULT_ENGINE;

        vaultsByChain[10_143].asset = WETH_MONAD_TESTNET_PERPS_ENGINE_VAULT_ASSET;
        vaultsByChain[10_143].priceAdapter = WETH_MONAD_TESTNET_PERPS_ENGINE_VAULT_PRICE_ADAPTER;
        vaultsByChain[10_143].engine = WETH_MONAD_TESTNET_PERPS_ENGINE_VAULT_ENGINE;

        vaultsByChain[31_337].asset = marginCollaterals[WETH_MARGIN_COLLATERAL_ID].marginCollateralAddress;
        vaultsByChain[31_337].priceAdapter = marginCollaterals[WETH_MARGIN_COLLATERAL_ID].priceAdapter;
        vaultsByChain[31_337].engine = address(0);

        VaultConfig memory wEthPerpsEngine = VaultConfig({
            vaultId: WETH_PERPS_ENGINE_VAULT_ID,
            depositCap: WETH_PERPS_ENGINE_VAULT_DEPOSIT_CAP,
            withdrawalDelay: WETH_PERPS_ENGINE_VAULT_WITHDRAWAL_DELAY,
            indexToken: address(0),
            asset: vaultsByChain[block.chainid].asset,
            creditRatio: WETH_PERPS_ENGINE_VAULT_CREDIT_RATIO,
            priceFeedHeartbeatSeconds: WETH_ARB_SEPOLIA_CHAINLINK_PRICE_FEED_HEARBEAT_SECONDS,
            isEnabled: WETH_PERPS_ENGINE_VAULT_IS_ENABLED,
            decimals: WETH_DECIMALS,
            priceAdapter: vaultsByChain[block.chainid].priceAdapter,
            vaultType: VaultTypes.Core,
            streamIdString: WETH_USD_ARB_SEPOLIA_STREAM_ID_STRING,
            streamId: WETH_USD_ARB_SEPOLIA_STREAM_ID,
            depositFee: WETH_PERPS_ENGINE_VAULT_DEPOSIT_FEE,
            redeemFee: WETH_PERPS_ENGINE_VAULT_REDEEM_FEE,
            engine: vaultsByChain[block.chainid].engine
        });
        vaultsConfig[WETH_PERPS_ENGINE_VAULT_ID] = wEthPerpsEngine;
    }

    function createVaults(
        IMarketMakingEngine marketMakingEngine,
        uint256 initialVaultId,
        uint256 finalVaultId,
        bool isTest,
        address testEngine
    )
        public
    {
        for (uint256 i = initialVaultId; i <= finalVaultId; i++) {
            if (isTest) {
                vaultsConfig[i].engine = testEngine;
            }

            marketMakingEngine.configureCollateral(
                vaultsConfig[i].asset,
                vaultsConfig[i].priceAdapter,
                vaultsConfig[i].creditRatio,
                vaultsConfig[i].isEnabled,
                vaultsConfig[i].decimals
            );

            Collateral.Data memory collateral = marketMakingEngine.getCollateralData(vaultsConfig[i].asset);

            marketMakingEngine.createVault(
                Vault.CreateParams({
                    vaultId: vaultsConfig[i].vaultId,
                    depositCap: vaultsConfig[i].depositCap,
                    withdrawalDelay: vaultsConfig[i].withdrawalDelay,
                    indexToken: vaultsConfig[i].indexToken, // ZLP Vault shares
                    collateral: collateral,
                    depositFee: vaultsConfig[i].depositFee,
                    redeemFee: vaultsConfig[i].redeemFee,
                    engine: vaultsConfig[i].engine
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

    function deployUsdTokenSwapKeeper(
        address deployer,
        address marketMakingEngine,
        address asset,
        string memory streamIdString
    )
        internal
        returns (address usdTokenSwapKeeper)
    {
        address usdTokenSwapKeeperImplementation = address(new UsdTokenSwapKeeper());

        usdTokenSwapKeeper = address(
            new ERC1967Proxy(
                usdTokenSwapKeeperImplementation,
                abi.encodeWithSelector(
                    UsdTokenSwapKeeper.initialize.selector,
                    deployer,
                    IMarketMakingEngine(marketMakingEngine),
                    asset,
                    streamIdString
                )
            )
        );

        usdTokenSwapKeepers[asset] = usdTokenSwapKeeper;

        changePrank({ msgSender: deployer });
        IMarketMakingEngine(marketMakingEngine).configureSystemKeeper(usdTokenSwapKeeper, true);

        console.log(
            "Usd Token Swap Keeper deployed at: %s, asset: %s, streamIdString: %s",
            usdTokenSwapKeeper,
            asset,
            streamIdString
        );
    }
}
