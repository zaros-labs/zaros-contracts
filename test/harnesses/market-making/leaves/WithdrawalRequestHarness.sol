// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { WithdrawalRequest } from "@zaros/market-making/leaves/WithdrawalRequest.sol";

contract WithdrawalRequestHarness {
    function exposed_WithdrawalRequest_load(
        uint256 vaultId,
        address account,
        uint256 withdrawalRequestId
    )
        external
        pure
        returns (WithdrawalRequest.Data memory)
    {
        WithdrawalRequest.Data memory withdrawRequestData =
            WithdrawalRequest.load(vaultId, account, withdrawalRequestId);

        return withdrawRequestData;
    }
}
