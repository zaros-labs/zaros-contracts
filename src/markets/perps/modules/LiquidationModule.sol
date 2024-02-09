// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { PerpsAccount } from "../storage/PerpsAccount.sol";
import { PerpMarket } from "../storage/PerpMarket.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

contract LiquidationModule {
    using EnumerableSet for EnumerableSet.UintSet;
    using PerpsAccount for PerpsAccount.Data;
    using PerpMarket for PerpMarket.Data;
    using SafeCast for uint256;

    modifier onlyRegisteredLiquidator() {
        _;
    }

    function checkLiquidatableAccounts(uint128[] calldata accountsIds)
        external
        view
        returns (uint128[] memory liquidatableAccountsIds)
    {
        for (uint256 i = 0; i < accountsIds.length; i++) {
            PerpsAccount.Data storage perpsAccount = PerpsAccount.load(accountsIds[i]);

            if (perpsAccount.isLiquidatable(ud60x18(0), sd59x18(0))) {
                liquidatableAccountsIds[liquidatableAccountsIds.length] = accountsIds[i];
            }
        }
    }

    function liquidateAccounts(uint128[] calldata accountsIds) external onlyRegisteredLiquidator {
        uint128[] memory liquidatableAccountsIds;
        for (uint256 i = 0; i < accountsIds.length; i++) {
            PerpsAccount.Data storage perpsAccount = PerpsAccount.load(accountsIds[i]);

            (UD60x18 requiredMarginUsdX18, SD59x18 accountTotalUnrealizedPnlUsdX18) =
                perpsAccount.getAccountMarginRequirementUsdAndUnrealizedPnlUsd(0, sd59x18(0));
            SD59x18 marginBalanceUsdX18 = perpsAccount.getMarginBalanceUsd(accountTotalUnrealizedPnlUsdX18);

            if (!perpsAccount.isLiquidatable(requiredMarginUsdX18, marginBalanceUsdX18)) {
                revert Errors.AccountNotLiquidatable(
                    accountsIds[i], requiredMarginUsdX18.intoUint256(), marginBalanceUsdX18.intoInt256()
                );
            }

            uint256 amountOfOpenPositions = perpsAccount.activeMarketsIds.length();

            for (uint256 j = 0; j < amountOfOpenPositions; j++) {
                uint128 marketId = perpsAccount.activeMarketsIds.at(j).toUint128();
                PerpMarket.Data storage perpMarket = PerpMarket.load(marketId);

                UD60x18 indexPriceX18 = perpMarket.getIndexPrice();
                // UD60x18 markPriceX18 = perpMarket.getMarkPrice(sd59x18(0), indexPriceX18);
            }
        }
    }
}
