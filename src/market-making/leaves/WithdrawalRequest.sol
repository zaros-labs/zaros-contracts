// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

library WithdrawalRequest {
    /// @notice ERC7201 storage location.
    bytes32 internal constant WITHDRAWAL_REQUEST_LOCATION =
        keccak256(abi.encode(uint256(keccak256("fi.zaros.market-making.WithdrawalRequest")) - 1));

    // TODO: pack storage slots
    struct Data {
        uint256 timestamp;
        uint256 shares;
        uint256 minAssets;
        bool fulfilled;
    }

    /// @notice Loads a {WithdrawalRequest} namespace.
    /// @param vaultId The vault identifier.
    /// @param account The withdrawal requester.
    /// @param withdrawalRequestId The withdrawal request identifier.
    /// @return withdrawalRequest The loaded withdrawal request storage pointer.
    function load(
        uint256 vaultId,
        address account,
        uint256 withdrawalRequestId
    )
        internal
        pure
        returns (Data storage withdrawalRequest)
    {
        bytes32 slot = keccak256(abi.encode(WITHDRAWAL_REQUEST_LOCATION, vaultId, account, withdrawalRequestId));
        assembly {
            withdrawalRequest.slot := slot
        }
    }
}
