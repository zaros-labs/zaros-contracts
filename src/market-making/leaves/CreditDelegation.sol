// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

library CreditDelegation {
    /// @notice ERC7201 storage location.
    bytes32 internal constant CREDIT_DELEGATION_LOCATION =
        keccak256(abi.encode(uint256(keccak256("fi.zaros.market-making.CreditDelegation")) - 1));

    struct Data {
        uint128 vaultId;
        uint128 marketId;
        uint128 weight;
        uint128 maxDebtPerShare;
    }

    /// @notice Loads a {CreditDelegation}.
    /// @param vaultId the Vault providing a share of its credit to the market.
    /// @param marketId the perp market receiving the credit.
    /// @return creditDelegation The loaded credit delegation storage pointer.
    function load(uint128 vaultId, uint256 marketId) internal pure returns (Data storage creditDelegation) {
        bytes32 slot = keccak256(abi.encode(CREDIT_DELEGATION_LOCATION, vaultId, marketId));
        assembly {
            creditDelegation.slot := slot
        }
    }
}
