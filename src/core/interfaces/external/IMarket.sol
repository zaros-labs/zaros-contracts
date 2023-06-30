//SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

/// TODO: Support ERC165
/// @title Interface for markets integrated with Zaros
interface IMarket {
    /// @notice returns a human-readable name for a given market
    function name(uint128 marketId) external view returns (string memory);

    /// @notice returns amount of USD that the market would try to mint256 if everything was withdrawn
    function reportedDebt(uint128 marketId) external view returns (uint256);

    /// @notice prevents reduction of available credit capacity by specifying this amount, for which withdrawals will be
    /// disallowed
    function minimumCredit(uint128 marketId) external view returns (uint256);
}
