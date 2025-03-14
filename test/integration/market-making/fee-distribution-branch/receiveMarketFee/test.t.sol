// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { CreditDelegationBranch } from "@zaros/market-making/branches/CreditDelegationBranch.sol";
import { VaultRouterBranch } from "@zaros/market-making/branches/VaultRouterBranch.sol";
import { MarketMakingEngineConfigurationBranch } from
    "@zaros/market-making/branches/MarketMakingEngineConfigurationBranch.sol";
import { Vault } from "@zaros/market-making/leaves/Vault.sol";
import { Market } from "@zaros/market-making/leaves/Market.sol";
import { CreditDelegation } from "@zaros/market-making/leaves/CreditDelegation.sol";
import { Distribution } from "@zaros/market-making/leaves/Distribution.sol";
import { MarketMakingEngineConfiguration } from "@zaros/market-making/leaves/MarketMakingEngineConfiguration.sol";
import { LiveMarkets } from "@zaros/market-making/leaves/LiveMarkets.sol";
import { Collateral } from "@zaros/market-making/leaves/Collateral.sol";
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";
import { EnumerableMap } from "@openzeppelin/utils/structs/EnumerableMap.sol";
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";

import "forge-std/Test.sol";

uint256 constant DEFAULT_DECIMAL = 18;

contract MockVault {
    function totalAssets() external pure returns (uint256) {
        return 1000 * (10 ** DEFAULT_DECIMAL);
    }
}

contract MockPriceAdapter {
    function getPrice() external pure returns (uint256) {
        return 10 ** DEFAULT_DECIMAL;
    }
}

contract MockEngine {
    function getUnrealizedDebt(uint128) external pure returns (int256) {
        return 0;
    }
}

contract WethRewardDistributionTest is
    CreditDelegationBranch,
    VaultRouterBranch,
    MarketMakingEngineConfigurationBranch,
    Test
{
    using Vault for Vault.Data;
    using Market for Market.Data;
    using CreditDelegation for CreditDelegation.Data;
    using Collateral for Collateral.Data;
    using SafeCast for uint256;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using LiveMarkets for LiveMarkets.Data;
    using MarketMakingEngineConfiguration for MarketMakingEngineConfiguration.Data;
    using Distribution for Distribution.Data;

    uint128 marketId = 1;
    address asset = vm.addr(1);
    address usdc = vm.addr(2);
    address weth = vm.addr(3);
    uint256 collateralAssetAmount = 100 * (10 ** DEFAULT_DECIMAL);
    uint256 usdcAmount = 200 * (10 ** DEFAULT_DECIMAL);
    uint256 creditRatio = 0.8e18;
    uint256[] vaultIds = new uint256[](2);

    function setUp() external {
        MockVault indexToken = new MockVault();
        MockPriceAdapter priceAdapter = new MockPriceAdapter();
        MockEngine mockEngine = new MockEngine();

        MarketMakingEngineConfiguration.Data storage configuration = MarketMakingEngineConfiguration.load();
        configuration.usdc = usdc;

        Market.Data storage market = Market.load(marketId);
        market.engine = address(mockEngine);
        uint256[] memory marketIds = new uint256[](1);
        marketIds[0] = uint256(marketId);
        vaultIds[0] = 1;
        vaultIds[1] = 2;
        market.id = marketId;

        LiveMarkets.Data storage liveMarkets = LiveMarkets.load();
        liveMarkets.addMarket(marketId);

        Collateral.Data storage collateral = Collateral.load(asset);
        collateral.priceAdapter = address(priceAdapter);
        collateral.creditRatio = creditRatio;

        for (uint128 vaultId = 1; vaultId <= 2; vaultId++) {
            Vault.Data storage vault = Vault.load(vaultId);
            vault.id = vaultId;
            vault.indexToken = address(indexToken);
            vault.collateral.decimals = uint8(DEFAULT_DECIMAL);
            vault.collateral.priceAdapter = address(priceAdapter);
            vault.collateral.creditRatio = creditRatio;
            vault.wethRewardDistribution.setActorShares(bytes32(0), ud60x18(1e18));
        }
        _connectVaultsAndMarkets();
    }

    function testWethRewardDistribution() external {
        uint256 wethRewardAmount = 1e18;

        _recalculateVaultsCreditCapacity();
        Market.Data storage market = Market.load(marketId);
        market.depositCredit(asset, ud60x18(collateralAssetAmount));
        market.settleCreditDeposit(usdc, ud60x18(100e18));
        // Market has received 1 WETH vault reward
        market.receiveWethReward(weth, ud60x18(0), ud60x18(wethRewardAmount));
        _recalculateVaultsCreditCapacity();

        uint256 totalWethToDistribute;
        for (uint128 vaultId = 1; vaultId <= 2; vaultId++) {
            Vault.Data storage vault = Vault.load(vaultId);
            Distribution.Data storage distribution = vault.wethRewardDistribution;
            assertGt(distribution.valuePerShare, 0);
            totalWethToDistribute +=
                ud60x18(distribution.totalShares).mul(ud60x18(uint256(distribution.valuePerShare))).unwrap();
        }

        assertEq(totalWethToDistribute, wethRewardAmount);
    }

    function _connectVaultsAndMarkets() internal {
        uint256[] memory marketIds = new uint256[](1);
        marketIds[0] = uint256(marketId);
        uint256[] memory _vaultIds = vaultIds;
        vm.startPrank(address(0));
        WethRewardDistributionTest(address(this)).connectVaultsAndMarkets(marketIds, _vaultIds);
        vm.stopPrank();
    }

    function _recalculateVaultsCreditCapacity() internal {
        WethRewardDistributionTest(address(this)).updateMarketCreditDelegations(marketId);
    }
}
