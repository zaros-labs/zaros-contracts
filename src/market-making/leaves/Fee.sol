// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Open Zeppelin dependencies
import { EnumerableMap } from "@openzeppelin/utils/structs/EnumerableMap.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

library Fee {
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    
    /// @notice ERC7201 storage location.
    bytes32 internal constant FEE_LOCATION =
        keccak256(abi.encode(uint256(keccak256("fi.zaros.market-making.Fee")) - 1));

    /// @param feeRecipientsPercentage The percentage of total accumulated weth to be allocated to fee recipients
    /// @param marketPercentage The percentage of total accumulated weth to be accolated to the market
    /// @param collectedMarketFees The collected fees in weth set for market
    /// @param collectedFeeRecipientsFees the collected fees in weth set for fee recipients
    /// @param receivedOrderFees An enumerable map that stores the amounts collected from each collateral type
    struct Data {
        uint128 feeRecipientsPercentage;
        uint128 marketPercentage;
        uint256 collectedMarketFees;
        uint256 collectedFeeRecipientsFees;
        EnumerableMap.AddressToUintMap receivedOrderFees;
    }

    /// @notice Loads a {Fee} namespace.
    /// @return fee The loaded fee storage pointer.
    function load() internal pure returns (Data storage fee) {
        bytes32 slot = keccak256(abi.encode(FEE_LOCATION));
        assembly {
            fee.slot := slot
        }
    }

    /// @notice Support function to calculate the accumulated wEth allocated for the beneficiary
    /// @param totalAmount The total amount or value to be distributed
    /// @param portion The portion or share that needs to be calculated
    /// @param denominator The denominator representing the total divisions or base value
    function calculateFees(
        UD60x18 totalAmount,
        UD60x18 portion,
        UD60x18 denominator
    )
        internal
        pure
        returns (uint256 amount)
    {
        UD60x18 accumulatedShareValue = totalAmount.mul(portion);
        amount = accumulatedShareValue.div(denominator).intoUint256();
    }
}