// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface ICurveRegistry {

    /// https://docs.curve.fi/integration/metaregistry/?h=find_pool_for_coins#find_pool_for_coins
    /// @notice Finds the pool address for a given pair of tokens, if it exists.
    /// @param _from The address of the input token.
    /// @param _to The address of the output token.
    /// @return The address of the pool supporting the token pair, or address(0) if no such pool exists.
    function find_pool_for_coins(address _from, address _to) external view returns (address);
}