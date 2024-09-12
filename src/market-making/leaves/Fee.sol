// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";

// Open Zeppelin dependencies
import { EnumerableMap } from "@openzeppelin/utils/structs/EnumerableMap.sol";

// Uniswap dependencies
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

library Fee {
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    
    /// @notice ERC7201 storage location.
    bytes32 internal constant FEE_LOCATION =
        keccak256(abi.encode(uint256(keccak256("fi.zaros.market-making.Fee")) - 1));
    bytes32 internal constant UNISWAP_LOCATION =
        keccak256(abi.encode(uint256(keccak256("fi.zaros.market-making.Uniswap")) - 1));

    uint256 internal constant BPS_DENOMINATOR = 10_000;

    /// @param feeRecipientsPercentage The percentage of total accumulated wEth to be allocated to fee recipients
    /// @param marketPercentage The percentage of total accumulated wEth to be accolated to the market
    /// @param collectedMarketFees The collected fees in wEth set for market
    /// @param collectedFeeRecipientsFees the collected fees in wEth set for fee recipients
    /// @param receivedOrderFees An enumerable map that stores the amounts collected from each collateral type
    struct Data {
        uint128 feeRecipientsPercentage;
        uint128 marketPercentage;
        uint256 collectedMarketFees;
        uint256 collectedFeeRecipientsFees;
        EnumerableMap.AddressToUintMap receivedOrderFees;
    }

    // Uniswap pool fee at 0.3%
    // Uniswap Router address
    // slippage value should be in bps (e.g 1% = 100bps)
    struct Uniswap {
        ISwapRouter swapRouter;
        uint24 poolFee;
        uint256 slippage;
    }

    /// @notice Loads a {Fee} namespace.
    /// @return fee The loaded fee storage pointer.
    function load(uint128 marketId) internal pure returns (Data storage fee) {
        bytes32 slot = keccak256(abi.encode(FEE_LOCATION, marketId));
        assembly {
            fee.slot := slot
        }
    }

    /// @notice Loads an { Uniswap } namespace.
    /// @return uniswap The loaded uniswap storage pointer.
    function load_Uniswap() internal pure returns (Uniswap storage uniswap){
        bytes32 slot = keccak256(abi.encode(UNISWAP_LOCATION));
        assembly {
            uniswap.slot := slot
        }
    }

    /// @notice Sets Uniswap Rounter address required for swapping tokens
    /// @return bool returns true if succesfully set
    function setUniswapRouterAddress(Uniswap storage self, address routerAddress) internal returns(bool) {
        if(routerAddress == address(0)) revert Errors.SwapRouterAddressUndefined();
        self.swapRouter = ISwapRouter(routerAddress);

        return true;
    }

    /// @notice Sets the pool fee
    /// @dev the minimum is 1000 (e.g. 0.1%)
    function setPoolFee(Uniswap storage self, uint24 newFee) internal {
        if(newFee < 1000) revert Errors.InvalidPoolFee();
        self.poolFee = newFee;
    }
    /// @notice Sets the slippage
    /// @dev the minimum is 100 (e.g. 1%)
    function setSlippage(Uniswap storage self, uint256 newSlippage) internal {
        if(newSlippage < 100) revert Errors.InvalidSlippage();
        self.slippage = newSlippage;
    }
}