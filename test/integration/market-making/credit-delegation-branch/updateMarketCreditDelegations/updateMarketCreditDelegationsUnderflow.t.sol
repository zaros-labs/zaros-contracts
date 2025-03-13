// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { CreditDelegationBranch } from "@zaros/market-making/branches/CreditDelegationBranch.sol";
import { VaultRouterBranch } from "@zaros/market-making/branches/VaultRouterBranch.sol";
import { MarketMakingEngineConfigurationBranch } from
    "@zaros/market-making/branches/MarketMakingEngineConfigurationBranch.sol";
import { Vault } from "@zaros/market-making/leaves/Vault.sol";
import { Market } from "@zaros/market-making/leaves/Market.sol";
import { CreditDelegation } from "@zaros/market-making/leaves/CreditDelegation.sol";
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
    uint256 price = 10 ** DEFAULT_DECIMAL;

    function getPrice() external view returns (uint256) {
        return price;
    }

    function setPrice(uint256 newPrice) external {
        price = newPrice;
    }
}

contract MockEngine {
    function getUnrealizedDebt(uint128) external pure returns (int256) {
        return 0;
    }
}

contract MarketMakingConfigurationBranchTest is
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

    uint128 marketId = 1;
    uint128 vaultId = 1;
    address asset = vm.addr(1);
    address usdc = vm.addr(2);
    address weth = vm.addr(3);
    uint256 collateralAssetAmount = 1000 * (10 ** DEFAULT_DECIMAL);
    uint256 creditRatio = 1e18;
    MockPriceAdapter priceAdapter;

    uint256[] vaultIds = new uint128[](1);

    function setUp() external {
        MockVault indexToken = new MockVault();
        priceAdapter = new MockPriceAdapter();
        MockEngine mockEngine = new MockEngine();

        MarketMakingEngineConfiguration.Data storage configuration = MarketMakingEngineConfiguration.load();
        configuration.usdc = usdc;

        Market.Data storage market = Market.load(marketId);
        market.engine = address(mockEngine);
        uint256[] memory marketIds = new uint256[](1);
        marketIds[0] = uint256(marketId);
        vaultIds[0] = uint256(vaultId);
        market.id = marketId;

        LiveMarkets.Data storage liveMarkets = LiveMarkets.load();
        liveMarkets.addMarket(marketId);

        Collateral.Data storage collateral = Collateral.load(asset);
        collateral.priceAdapter = address(priceAdapter);
        collateral.creditRatio = creditRatio;

        Vault.Data storage vault = Vault.load(vaultId);
        vault.id = vaultId;
        vault.indexToken = address(indexToken);
        vault.collateral.decimals = uint8(DEFAULT_DECIMAL);
        vault.collateral.priceAdapter = address(priceAdapter);
        vault.collateral.creditRatio = creditRatio;

        uint256[] memory _vaultIds = vaultIds;
        _connectVaultsAndMarkets(_vaultIds);
    }

    function testRevertWhenCreditDepositDrop() external {
        Market.Data storage market = Market.load(marketId);

        _recalculateVaultsCreditCapacity();

        market.depositCredit(asset, ud60x18(collateralAssetAmount));
        market.settleCreditDeposit(usdc, ud60x18(300e18));
        market.receiveWethReward(weth, ud60x18(0), ud60x18(1e18));

        _recalculateVaultsCreditCapacity();

        priceAdapter.setPrice(0.9e18); // price dropped from 1 usd to 0.9 usd

        // vm.expectRevert(stdError.arithmeticError);
        vm.expectEmit();
        emit Vault.LogUpdateVaultCreditCapacity(vaultId, 1e17, 0, 0, 0, 899_900_000_000_000_000_000);

        _recalculateVaultsCreditCapacity();
    }

    function _connectVaultsAndMarkets(uint256[] memory _vaultIds) internal {
        uint256[] memory marketIds = new uint256[](1);
        marketIds[0] = uint256(marketId);
        vm.startPrank(address(0));
        MarketMakingConfigurationBranchTest(address(this)).connectVaultsAndMarkets(marketIds, _vaultIds);
        vm.stopPrank();
    }

    function _recalculateVaultsCreditCapacity() internal {
        MarketMakingConfigurationBranchTest(address(this)).updateMarketCreditDelegations(marketId);
    }
}
