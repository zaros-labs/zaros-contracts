// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { IPriceAdapter } from "@zaros/utils/interfaces/IPriceAdapter.sol";
import { ISwapAssetConfig } from "@zaros/utils/interfaces/ISwapAssetConfig.sol";
import { Math } from "@zaros/utils/Math.sol";

// Open zeppelin dependencies
import { Ownable } from "@openzeppelin/access/Ownable.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

/// @notice Swap asset configuration
/// @param decimals The asset decimals
/// @param priceAdapter The asset price adapter
struct SwapAssetConfigData {
    uint8 decimals;
    address priceAdapter;
}

contract SwapAssetConfig is Ownable, ISwapAssetConfig {
    /// @notice Event emitted when the new swap asset config data is set
    /// @param asset The asset address
    /// @param decimals The asset decimals
    /// @param priceAdapter The asset price adapter
    event LogSetSwapAssetConfig(address indexed asset, uint8 decimals, address priceAdapter);

    /// @notice The asset data
    mapping(address asset => SwapAssetConfigData data) public swapAssetConfigData;

    constructor() Ownable(msg.sender) {}

    /// @notice Sets the swap asset config data
    /// @dev The asset config data is used to calculate the expected output amount
    /// @dev Only the owner can set the asset config data
    /// @param asset The asset address
    /// @param decimals The asset decimals
    /// @param priceAdapter The asset price adapter
    function setSwapAssetConfig(address asset, uint8 decimals, address priceAdapter) public onlyOwner {
        // set the swap asset config data
        swapAssetConfigData[asset] = SwapAssetConfigData(decimals, priceAdapter);

        // emit the event
        emit LogSetSwapAssetConfig(asset, decimals, priceAdapter);
    }

    /// @notice Get the expected output amount
    /// @param tokenIn The token in address
    /// @param tokenOut The token out address
    /// @param amountIn The amount int address
    /// @return expectedAmountOut The expected amount out
    function getExpectedOutput(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    )
        public
        view
        returns (uint256 expectedAmountOut)
    {
        // get the price of the tokenIn
        UD60x18 priceTokenInX18 = IPriceAdapter(swapAssetConfigData[tokenIn].priceAdapter).getPrice();

        // get the price of the tokenOut
        UD60x18 priceTokenOutX18 = IPriceAdapter(swapAssetConfigData[tokenOut].priceAdapter).getPrice();

        // convert the amount in to UD60x18
        UD60x18 amountInX18 = Math.convertTokenAmountToUd60x18(swapAssetConfigData[tokenIn].decimals, amountIn);

        // calculate the expected amount out
        expectedAmountOut = Math.convertUd60x18ToTokenAmount(
            swapAssetConfigData[tokenOut].decimals, amountInX18.mul(priceTokenInX18).div(priceTokenOutX18)
        );
    }
}