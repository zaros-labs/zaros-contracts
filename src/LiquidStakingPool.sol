// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

// TODO: implement
struct SwapRequest {
    bool todo;
}

contract LiquidStakingPool {
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
