// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Margin Collaterals
import { Usdc } from "script/marginCollaterals/Usdc.sol";
import { Usdz } from "script/marginCollaterals/Usdz.sol";
import { WeEth } from "script/marginCollaterals/WeEth.sol";
import { WstEth } from "script/marginCollaterals/WstEth.sol";

contract MarginCollaterals is Usdc, Usdz, WeEth, WstEth {
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
