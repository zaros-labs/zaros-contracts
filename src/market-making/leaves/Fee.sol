// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Open Zeppelin dependencies
import { EnumerableMap } from "@openzeppelin/utils/structs/EnumerableMap.sol";

// PRB Math dependencies
import "@prb-math/Common.sol";

library Fee {
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    /// @notice ERC7201 storage location.
    bytes32 internal constant FEE_LOCATION =
        keccak256(abi.encode(uint256(keccak256("fi.zaros.market-making.Fee")) - 1));

    // TODO: use share instead of percentage or portion
    /// @param feeRecipientsPercentage The percentage of total accumulated weth to be allocated to fee recipients
    /// @param marketPercentage The percentage of total accumulated weth to be allocated to the market
    /// @param collectedFees the collected fees in weth set for fee recipients
    /// @param receivedOrderFees An enumerable map that stores the amounts collected from each collateral type
    struct Data {
        uint128 feeRecipientsShare;
        uint128 marketShare;
        uint128 collectedFees;
        EnumerableMap.AddressToUintMap receivedMarketFees;
    }

    /// @notice Loads a {Fee} namespace.
    /// @return fee The loaded fee storage pointer.
    function load(uint128 marketId) internal pure returns (Data storage fee) {
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
        uint256 totalAmount,
        uint256 portion,
        uint256 denominator
    )
        internal
        pure
        returns (uint128 amount)
    {
        amount = uint128(mulDiv(totalAmount, portion, denominator));
    }

    function increment(Data storage self, address recipient, uint256 amount) internal { }
}
