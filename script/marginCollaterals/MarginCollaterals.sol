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
    }

    mapping(uint256 marginCollateralId => MarginCollateral marginCollateral) internal marginCollaterals;

    function setupMarginCollaterals() internal {
        MarginCollateral memory usdcConfig = MarginCollateral({
            marginCollateralId: USDC_MARGIN_COLLATERAL_ID,
            depositCap: USDC_DEPOSIT_CAP,
            loanToValue: USDC_LOAN_TO_VALUE,
            minDepositMargin: USDC_MIN_DEPOSIT_MARGIN,
            mockUsdPrice: MOCK_USDC_USD_PRICE
        });
        marginCollaterals[USDC_MARGIN_COLLATERAL_ID] = usdcConfig;

        MarginCollateral memory usdzConfig = MarginCollateral({
            marginCollateralId: USDZ_MARGIN_COLLATERAL_ID,
            depositCap: USDZ_DEPOSIT_CAP,
            loanToValue: USDZ_LOAN_TO_VALUE,
            minDepositMargin: USDZ_MIN_DEPOSIT_MARGIN,
            mockUsdPrice: MOCK_USDZ_USD_PRICE
        });
        marginCollaterals[USDZ_MARGIN_COLLATERAL_ID] = usdzConfig;

        MarginCollateral memory wstEth = MarginCollateral({
            marginCollateralId: WSTETH_MARGIN_COLLATERAL_ID,
            depositCap: WSTETH_DEPOSIT_CAP,
            loanToValue: WSTETH_LOAN_TO_VALUE,
            minDepositMargin: WSTETH_MIN_DEPOSIT_MARGIN,
            mockUsdPrice: MOCK_WSTETH_USD_PRICE
        });
        marginCollaterals[WSTETH_MARGIN_COLLATERAL_ID] = wstEth;

        MarginCollateral memory weEth = MarginCollateral({
            marginCollateralId: WEETH_MARGIN_COLLATERAL_ID,
            depositCap: WEETH_DEPOSIT_CAP,
            loanToValue: WEETH_LOAN_TO_VALUE,
            minDepositMargin: WEETH_MIN_DEPOSIT_MARGIN,
            mockUsdPrice: MOCK_WEETH_USD_PRICE
        });
        marginCollaterals[WEETH_MARGIN_COLLATERAL_ID] = weEth;
    }
}
