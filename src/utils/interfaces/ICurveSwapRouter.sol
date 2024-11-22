// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface ICurveSwapRouter {

    /// https://docs.curve.fi/router/CurveRegistryExchange/?h=#exchange_with_best_rate
    /// @notice Finds the best rate and performs a swap between two tokens
    /// @param _from The address of the token to swap from
    /// @param _to The address of the token to swap to
    /// @param _amount The amount of `fromToken` to swap
    /// @param _expected The minimum acceptable amount of `toToken` to receive
    /// @param _receiver The address to receive the output tokens (defaults to msg.sender if not provided)
    /// @return amountOut The actual amount of `toToken` received
    function exchange_with_best_rate(
        address _from,
        address _to,
        uint256 _amount,
        uint256 _expected,
        address _receiver
    ) external payable returns (uint256 amountOut);

    /// https://docs.curve.fi/router/CurveRegistryExchange/?h=#exchange_multiple
    /// @notice Perform a multi-hop exchange across Curve pools
    /// @param _route An array of up to 9 addresses (tokens and pools) defining the swap path
    /// @param _swap_params An array of 4 sets of 3 parameters (indexIn, indexOut, swapType) for each step in the route
    /// @param _amount The amount of the input token to swap
    /// @param _expected The minimum amount of the output token expected
    /// @param _pools An optional array of up to 4 pool addresses used in the swap
    /// @param _receiver The address to receive the output tokens (defaults to msg.sender)
    /// @return amountOut The amount of the output token received
    function exchange_multiple(
        address[9] calldata _route,
        uint256[3][4] calldata _swap_params,
        uint256 _amount,
        uint256 _expected,
        address[4] calldata _pools,
        address _receiver
    ) external payable returns (uint256 amountOut);
}