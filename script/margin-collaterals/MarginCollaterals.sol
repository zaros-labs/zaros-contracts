// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Margin Collaterals
import { Usdz } from "script/margin-collaterals/Usdz.sol";
import { Usdc } from "script/margin-collaterals/Usdc.sol";
import { WEth } from "script/margin-collaterals/WEth.sol";
import { WBtc } from "script/margin-collaterals/WBtc.sol";
import { WstEth } from "script/margin-collaterals/WstEth.sol";
import { WeEth } from "script/margin-collaterals/WeEth.sol";

contract MarginCollaterals is Usdz, Usdc, WEth, WBtc, WstEth, WeEth {
    struct MarginCollateral {
        uint256 marginCollateralId;
        uint128 depositCap;
        uint120 loanToValue;
        uint256 minDepositMargin;
        uint256 mockUsdPrice;
        address marginCollateralAddress;
        address priceFeed;
        uint256 liquidationPriority;
    }

    mapping(uint256 marginCollateralId => MarginCollateral marginCollateral) internal marginCollaterals;

    function setupMarginCollaterals() internal {
        MarginCollateral memory usdcConfig = MarginCollateral({
            marginCollateralId: USDC_MARGIN_COLLATERAL_ID,
            depositCap: USDC_DEPOSIT_CAP,
            loanToValue: USDC_LOAN_TO_VALUE,
            minDepositMargin: USDC_MIN_DEPOSIT_MARGIN,
            mockUsdPrice: MOCK_USDC_USD_PRICE,
            marginCollateralAddress: USDC_ADDRESS,
            priceFeed: USDC_PRICE_FEED,
            liquidationPriority: USDC_LIQUIDATION_PRIORITY
        });
        marginCollaterals[USDC_MARGIN_COLLATERAL_ID] = usdcConfig;

        MarginCollateral memory usdzConfig = MarginCollateral({
            marginCollateralId: USDZ_MARGIN_COLLATERAL_ID,
            depositCap: USDZ_DEPOSIT_CAP,
            loanToValue: USDZ_LOAN_TO_VALUE,
            minDepositMargin: USDZ_MIN_DEPOSIT_MARGIN,
            mockUsdPrice: MOCK_USDZ_USD_PRICE,
            marginCollateralAddress: USDZ_ADDRESS,
            priceFeed: USDZ_PRICE_FEED,
            liquidationPriority: USDZ_LIQUIDATION_PRIORITY
        });
        marginCollaterals[USDZ_MARGIN_COLLATERAL_ID] = usdzConfig;

        MarginCollateral memory wEth = MarginCollateral({
            marginCollateralId: WETH_MARGIN_COLLATERAL_ID,
            depositCap: WETH_DEPOSIT_CAP,
            loanToValue: WETH_LOAN_TO_VALUE,
            minDepositMargin: WETH_MIN_DEPOSIT_MARGIN,
            mockUsdPrice: MOCK_WETH_USD_PRICE,
            marginCollateralAddress: WETH_ADDRESS,
            priceFeed: WETH_PRICE_FEED,
            liquidationPriority: WETH_LIQUIDATION_PRIORITY
        });
        marginCollaterals[WETH_MARGIN_COLLATERAL_ID] = wEth;

        MarginCollateral memory wBtc = MarginCollateral({
            marginCollateralId: WBTC_MARGIN_COLLATERAL_ID,
            depositCap: WBTC_DEPOSIT_CAP,
            loanToValue: WBTC_LOAN_TO_VALUE,
            minDepositMargin: WBTC_MIN_DEPOSIT_MARGIN,
            mockUsdPrice: MOCK_WBTC_USD_PRICE,
            marginCollateralAddress: WBTC_ADDRESS,
            priceFeed: WBTC_PRICE_FEED,
            liquidationPriority: WBTC_LIQUIDATION_PRIORITY
        });
        marginCollaterals[WBTC_MARGIN_COLLATERAL_ID] = wBtc;

        MarginCollateral memory wstEth = MarginCollateral({
            marginCollateralId: WSTETH_MARGIN_COLLATERAL_ID,
            depositCap: WSTETH_DEPOSIT_CAP,
            loanToValue: WSTETH_LOAN_TO_VALUE,
            minDepositMargin: WSTETH_MIN_DEPOSIT_MARGIN,
            mockUsdPrice: MOCK_WSTETH_USD_PRICE,
            marginCollateralAddress: WSTETH_ADDRESS,
            priceFeed: WSTETH_PRICE_FEED,
            liquidationPriority: WSTETH_LIQUIDATION_PRIORITY
        });
        marginCollaterals[WSTETH_MARGIN_COLLATERAL_ID] = wstEth;

        MarginCollateral memory weEth = MarginCollateral({
            marginCollateralId: WEETH_MARGIN_COLLATERAL_ID,
            depositCap: WEETH_DEPOSIT_CAP,
            loanToValue: WEETH_LOAN_TO_VALUE,
            minDepositMargin: WEETH_MIN_DEPOSIT_MARGIN,
            mockUsdPrice: MOCK_WEETH_USD_PRICE,
            marginCollateralAddress: WEETH_ADDRESS,
            priceFeed: WEETH_PRICE_FEED,
            liquidationPriority: WEETH_LIQUIDATION_PRIORITY
        });
        marginCollaterals[WEETH_MARGIN_COLLATERAL_ID] = weEth;
    }

    function getFilteredMarginCollateralsConfig(uint256[2] memory marginCollateralIdsRange)
        internal
        view
        returns (MarginCollateral[] memory)
    {
        uint256 initialMarginCollateralId = marginCollateralIdsRange[0];
        uint256 finalMarginCollateralId = marginCollateralIdsRange[1];
        uint256 filteredMarketsLength = finalMarginCollateralId - initialMarginCollateralId + 1;

        MarginCollateral[] memory filteredMarginCollateralsConfig = new MarginCollateral[](filteredMarketsLength);

        uint256 nextMarginCollateralId = initialMarginCollateralId;
        for (uint256 i = 0; i < filteredMarketsLength; i++) {
            filteredMarginCollateralsConfig[i] = marginCollaterals[nextMarginCollateralId];
            nextMarginCollateralId++;
        }

        return filteredMarginCollateralsConfig;
    }
}
