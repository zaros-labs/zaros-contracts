// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Open Zeppelin dependencies
import { IERC4626 } from "@openzeppelin/token/ERC20/extensions/ERC4626.sol";

/// @dev TODO: define events
interface IStrategy is IERC4626 {
    function setAllowances(uint256 amount, bool shouldIncrease) external;

    function collectRewards(uint256[] calldata minAmountsOut) external returns (uint256);

    function addLiquidityToPool(uint256 minBptOut) external;

    function removeLiquidityFromPool(uint256 bptAmountIn, uint256[] calldata minAmountsOut) external;
}
