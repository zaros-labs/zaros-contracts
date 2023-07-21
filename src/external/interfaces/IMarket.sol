//SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

/// @title Interface for markets integrated with Zaros
interface IMarket {
    /// @notice returns a human-readable name for a given market
    function name() external view returns (string memory);

    /// @notice returns amount of USD that the market would try to mint256 if everything was withdrawn
    function reportedDebt() external view returns (uint256);

    /// @notice prevents reduction of available credit capacity by specifying this amount, for which withdrawals will be
    /// disallowed
    function minimumCredit() external view returns (uint256);
}
