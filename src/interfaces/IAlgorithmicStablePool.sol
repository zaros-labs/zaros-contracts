// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Balancer dependencies
import { IGeneralPool, IBasePool } from "@balancer-labs/v2-interfaces/contracts/vault/IGeneralPool.sol";

interface AlgorithmicStablePool is IGeneralPool {
    /// @inheritdoc IBasePool
    function getPoolId() external view returns (bytes32);

    /// @inheritdoc IBasePool
    function getSwapFeePercentage() external view returns (uint256);

    /// @inheritdoc IBasePool
    function getScalingFactors() external view returns (uint256[] memory);

    /// @inheritdoc IBasePool
    function onJoinPool(
        bytes32 poolId,
        address sender,
        address recipient,
        uint256[] memory balances,
        uint256 lastChangeBlock,
        uint256 protocolSwapFeePercentage,
        bytes memory userData
    )
        external
        returns (uint256[] memory amountsIn, uint256[] memory dueProtocolFeeAmounts);

    /// @inheritdoc IBasePool
    function onExitPool(
        bytes32 poolId,
        address sender,
        address recipient,
        uint256[] memory balances,
        uint256 lastChangeBlock,
        uint256 protocolSwapFeePercentage,
        bytes memory userData
    )
        external
        returns (uint256[] memory amountsOut, uint256[] memory dueProtocolFeeAmounts);

    /// @inheritdoc IGeneralPool
    function onSwap(
        SwapRequest memory swapRequest,
        uint256[] memory balances,
        uint256 indexIn,
        uint256 indexOut
    )
        external
        override
        returns (uint256 amount);

    function queryJoin(
        bytes32 poolId,
        address sender,
        address recipient,
        uint256[] memory balances,
        uint256 lastChangeBlock,
        uint256 protocolSwapFeePercentage,
        bytes memory userData
    )
        external
        returns (uint256 bptOut, uint256[] memory amountsIn);

    function queryExit(
        bytes32 poolId,
        address sender,
        address recipient,
        uint256[] memory balances,
        uint256 lastChangeBlock,
        uint256 protocolSwapFeePercentage,
        bytes memory userData
    )
        external
        returns (uint256 bptIn, uint256[] memory amountsOut);
}
