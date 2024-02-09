// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { PerpsAccount } from "../storage/PerpsAccount.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

contract LiquidationModule {
    using PerpsAccount for PerpsAccount.Data;

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

            UD60x18 requiredMarginUsdX18;
            SD59x18 marginBalanceUsdX18;

            if (!perpsAccount.isLiquidatable(requiredMarginUsdX18, marginBalanceUsdX18)) {
                revert Errors.AccountNotLiquidatable(
                    accountsIds[i], requiredMarginUsdX18.intoUint256(), marginBalanceUsdX18.intoInt256()
                );
            }
        }
    }
}
