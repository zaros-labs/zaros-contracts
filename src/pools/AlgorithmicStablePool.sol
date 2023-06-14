// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { IAlgorithmicStablePool } from "../interfaces/IAlgorithmicStablePool.sol";

contract AlgorithmicStablePool is IAlgorithmicStablePool {
    /// @inheritdoc IAlgorithmicStablePool
    function getPoolId() external view returns (bytes32) { }

    /// @inheritdoc IAlgorithmicStablePool
    function getSwapFeePercentage() external view returns (uint256) { }

    /// @inheritdoc IAlgorithmicStablePool
    function getScalingFactors() external view returns (uint256[] memory) { }

    /// @inheritdoc IAlgorithmicStablePool
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
        returns (uint256[] memory amountsIn, uint256[] memory dueProtocolFeeAmounts)
    { }

    /// @inheritdoc IAlgorithmicStablePool
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
        returns (uint256[] memory amountsOut, uint256[] memory dueProtocolFeeAmounts)
    { }

    /// @inheritdoc IAlgorithmicStablePool
    function onSwap(
        SwapRequest memory swapRequest,
        uint256[] memory balances,
        uint256 indexIn,
        uint256 indexOut
    )
        external
        override
        returns (uint256 amount)
    { }

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
        returns (uint256 bptOut, uint256[] memory amountsIn)
    { }

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
        returns (uint256 bptIn, uint256[] memory amountsOut)
    { }

    function _swapGivenIn(
        SwapRequest memory swapRequest,
        uint256[] memory registeredBalances,
        uint256 registeredIndexIn,
        uint256 registeredIndexOut,
        uint256[] memory scalingFactors
    )
        internal
        virtual
        returns (uint256)
    { }

    function _swapGivenOut(
        SwapRequest memory swapRequest,
        uint256[] memory registeredBalances,
        uint256 registeredIndexIn,
        uint256 registeredIndexOut,
        uint256[] memory scalingFactors
    )
        internal
        virtual
        returns (uint256)
    { }

    function _onSwapGivenIn(
        SwapRequest memory request,
        uint256[] memory registeredBalances,
        uint256 registeredIndexIn,
        uint256 registeredIndexOut
    )
        internal
        virtual
        returns (uint256)
    { }

    function _onSwapGivenOut(
        SwapRequest memory request,
        uint256[] memory registeredBalances,
        uint256 registeredIndexIn,
        uint256 registeredIndexOut
    )
        internal
        virtual
        returns (uint256)
    { }

    function _onRegularSwap(
        bool isGivenIn,
        uint256 amountGiven,
        uint256[] memory registeredBalances,
        uint256 registeredIndexIn,
        uint256 registeredIndexOut
    )
        private
        view
        returns (uint256)
    { }

    function _swapWithBpt(
        SwapRequest memory swapRequest,
        uint256[] memory registeredBalances,
        uint256 registeredIndexIn,
        uint256 registeredIndexOut,
        uint256[] memory scalingFactors
    )
        private
        returns (uint256)
    { }

    function _doJoinSwap(
        bool isGivenIn,
        uint256 amount,
        uint256[] memory balances,
        uint256 indexIn,
        uint256 currentAmp,
        uint256 actualSupply,
        uint256 preJoinExitInvariant
    )
        internal
        view
        returns (uint256, uint256)
    { }
}
