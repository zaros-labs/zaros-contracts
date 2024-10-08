// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import { UD60x18 } from "@prb-math/UD60x18.sol";

library CreditDeposit {
    /// @notice ERC7201 storage location.
    bytes32 internal constant CREDIT_DEPOSIT_LOCATION =
        keccak256(abi.encode(uint256(keccak256("fi.zaros.market-making.CreditDeposit")) - 1));

    /// @notice {CreditDeposit} namespace storage structure.
    /// @param value the amount of assets deposited in 18 decimals.
    /// @param lastDistributedValue the amount of assets that have been last distributed to vaults in 18 decimals.
    struct Data {
        uint128 value;
        uint128 lastDistributedValue;
    }

    /// @notice Load a {CreditDeposit}.
    /// @param marketId The id of the market that owns this credit deposit.
    /// @param asset The address of the collateral type used for this deposit.
    function load(uint128 marketId, address asset) internal pure returns (Data storage creditDeposit) {
        bytes32 slot = keccak256(abi.encode(CREDIT_DEPOSIT_LOCATION, asset));
        assembly {
            creditDeposit.slot := slot
        }
    }

    /// @notice Adds an amount of assets to the credit deposit.
    /// @param self The credit deposit storage pointer.
    /// @param amountX18 The amount of deposited assets in 18 decimals.
    function add(Data storage self, UD60x18 amountX18) internal {
        self.value += amountX18.intoUint128();
    }
}
