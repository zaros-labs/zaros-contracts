// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

library UsdTokenSwapConfig {
    /// @notice ERC7201 storage location.
    bytes32 internal constant SWAP_LOCATION =
        keccak256(abi.encode(uint256(keccak256("fi.zaros.market-making.Swap")) - 1));

    /// @notice Emitted when the USD token swap configuration is updated.
    /// @param baseFeeUsd The updated base fee in USD.
    /// @param swapSettlementFeeBps The updated swap settlement fee in basis points.
    /// @param maxExecutionTime The updated maximum execution time in seconds.
    event LogUpdateUsdTokenSwapConfig(uint128 baseFeeUsd, uint128 swapSettlementFeeBps, uint128 maxExecutionTime);

    /// @notice Represents a swap request for a user.
    /// @param processed Indicates whether the swap has been processed.
    /// @param amountIn The amount of the input asset provided for the swap.
    /// @param minAmountOut The min amount of the output asset expected after the swap.
    /// @param deadline The deadline by which the swap must be fulfilled.
    /// @param assetOut The address of the asset to be received as the output of the swap.
    /// @param vaultId The id of the vault associated with the swap.
    struct SwapRequest {
        bool processed;
        uint120 deadline;
        uint128 amountIn;
        address assetOut;
        uint128 vaultId;
        uint128 minAmountOut;
    }

    /// @notice Represents the configuration and state data for USD token swaps.
    /// @param baseFeeUsd The flat fee for each swap, denominated in USD.
    /// @param swapSettlementFeeBps The swap settlement fee in basis points (bps), applied as a percentage of the swap
    /// amount.
    /// @param maxExecutionTime The maximum allowed time, in seconds, to execute a swap after it has been requested.
    /// @param usdcAvailableForEngine The amount of USDC backing an engine's usd token, coming from vaults that had
    /// their debt settled, allocating the usdc acquired to users of that engine. Note: usdc stored here isn't owned
    // by any vault, it's where usdc from settled vaults is stored, to be used for swaps, although swaps can
    // also be done using a vault's deposited usdc.
    /// @param swapRequestIdCounter A counter for tracking the number of swap requests per user address.
    /// @param swapRequests A mapping that tracks all swap requests for each user, by user address and swap request
    /// id.
    struct Data {
        uint128 baseFeeUsd; // 1 USD
        uint128 swapSettlementFeeBps; // 0.3 %
        uint128 maxExecutionTime;
        uint128 pdCurveMinX;
        uint128 pdCurveMaxX;
        uint128 debtTvlRatioEndThreshold;
        mapping(address engine => uint256 availableUsdc) usdcAvailableForEngine;
        mapping(address => uint128) swapRequestIdCounter;
        mapping(address => mapping(uint128 => SwapRequest)) swapRequests;
    }

    /// @notice Loads the {UsdTokenSwapConfig}.
    /// @return usdTokenSwapConfig The loaded usd token swap config data storage pointer.
    function load() internal pure returns (Data storage usdTokenSwapConfig) {
        bytes32 slot = keccak256(abi.encode(SWAP_LOCATION));
        assembly {
            usdTokenSwapConfig.slot := slot
        }
    }

    // function applyPremiumOrDiscountToAmountOut(
    //     UD60x18 assetAmountOutX18,
    //     SD59x18 vaultDebtRatioX18
    // ) internal pure returns (UD60x18) {

    // {
    // }

    // function getPremiumDiscountFactor(UD60x18 vaulAssetsValueUsdX18, SD59x18 vaultDebtUsdX18) internal pure returns
    // (SD59x18 pdFactorX18) {
    //     //   SD59x18 sdDelegatedCreditUsdX18 = delegatedCreditUsdX18.intoSD59x18();
    //     // if (sdDelegatedCreditUsdX18.lte(totalDebtUsdX18) || sdDelegatedCreditUsdX18.isZero()) {
    //     //     autoDeleverageFactorX18 = UD60x18_UNIT;
    //     //     return autoDeleverageFactorX18;
    //     // }

    //     // UD60x18 -> SD59x18
    //     SD59x18 sdVaultAssetsValueUsdX18 = vaulAssetsValueUsdX18.intoSD59x18();

    //     // cache the vault's tvl / debt value, positive means we'll apply a discount, negative means we'll apply a
    // premium
    //     SD59x18 vaultDebtTvlRatio = vaultDebtUsdX18.div(sdVaultAssetsValueUsdX18);

    //     // cache the auto deleverage parameters as UD60x18
    //     UD60x18 autoDeleverageStartThresholdX18 = ud60x18(self.autoDeleverageStartThreshold);
    //     UD60x18 autoDeleverageEndThresholdX18 = ud60x18(self.autoDeleverageEndThreshold);
    //     UD60x18 autoDeleverageExpoentZX18 = ud60x18(self.autoDeleverageExpoentZ);

    //     // first, calculate the unscaled delevarage factor
    //     UD60x18 unscaledDeleverageFactor = Math.min(marketDebtRatio, autoDeleverageEndThresholdX18).sub(
    //         autoDeleverageStartThresholdX18
    //     ).div(autoDeleverageEndThresholdX18.sub(autoDeleverageStartThresholdX18));

    //     // finally, raise to the power scale
    //     autoDeleverageFactorX18 = unscaledDeleverageFactor.pow(autoDeleverageExpoentZX18);
    // }

    /// @notice Updates the fee and execution time parameters for USD token swaps.
    /// @param baseFeeUsd The new flat fee for each swap, denominated in USD.
    /// @param swapSettlementFeeBps The new swap settlement fee in basis points (bps), applied as a percentage of the
    /// swap amount.
    /// @param maxExecutionTime The new maximum allowed time, in seconds, to execute a swap after it has been
    /// requested.
    function update(uint128 baseFeeUsd, uint128 swapSettlementFeeBps, uint128 maxExecutionTime) internal {
        Data storage self = load();

        self.baseFeeUsd = baseFeeUsd;
        self.swapSettlementFeeBps = swapSettlementFeeBps;
        self.maxExecutionTime = maxExecutionTime;

        emit LogUpdateUsdTokenSwapConfig(baseFeeUsd, swapSettlementFeeBps, maxExecutionTime);
    }

    /// @notice Increments and returns the next swap request ID for a given user.
    /// @dev This function updates the `swapRequestIdCounter` mapping to generate a unique ID for each user's swap
    /// request.
    /// @param user The address of the user for whom the next swap request ID is being generated.
    /// @return id The new incremented swap request ID for the specified user.
    function nextId(Data storage self, address user) internal returns (uint128 id) {
        return ++self.swapRequestIdCounter[user];
    }
}
