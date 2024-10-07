// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Open Zeppelin dependencies
import { EnumerableMap } from "@openzeppelin/utils/structs/EnumerableMap.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

library Fee {
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    /// @notice ERC7201 storage location.
    bytes32 internal constant FEE_LOCATION =
        keccak256(abi.encode(uint256(keccak256("fi.zaros.market-making.Fee")) - 1)) & ~bytes32(uint256(0xff));

    /// @param feeRecipientsShare The percentage of total accumulated weth to be allocated to fee recipients
    /// @param marketShare The percentage of total accumulated weth to be allocated to the market
    /// @param collectedFees the collected fees in weth set for fee recipients
    /// @param receivedMarketFees An enumerable map that stores the amounts collected from each collateral type
    struct Data {
        uint128 feeRecipientsShare;
        uint128 marketShare;
        uint256 collectedFees;
        EnumerableMap.AddressToUintMap receivedMarketFees;
    }

    /// @notice Loads a {Fee} namespace.
    /// @param marketId The market id.
    /// @return fee The loaded fee storage pointer.
    function load(uint128 marketId) internal pure returns (Data storage fee) {
        bytes32 slot = keccak256(abi.encode(FEE_LOCATION, marketId));
        assembly {
            fee.slot := slot
        }
    }

    /// @notice Support function to calculate the accumulated wEth allocated for the beneficiary
    /// @param totalAmountX18 The total amount or value to be distributed
    /// @param shareX18 The share that needs to be calculated
    /// @param denominatorX18 The denominator representing the total divisions or base value
    /// @return amountX18 The calculated amount to be distributed
    function calculateFees(
        UD60x18 totalAmountX18,
        UD60x18 shareX18,
        UD60x18 denominatorX18
    )
        internal
        pure
        returns (UD60x18 amountX18)
    {
        amountX18 = (totalAmountX18.mul(shareX18)).div(denominatorX18);
    }

    /// @notice Support function to increment the received fees for a specific asset
    /// @param self The fee storage pointer
    /// @param asset The asset address
    /// @param amountX18 The amount to be incremented
    function incrementReceivedMarketFees(Data storage self, address asset, UD60x18 amountX18) internal {
        UD60x18 newAmount = amountX18.add(ud60x18(self.receivedMarketFees.get(asset)));

        self.receivedMarketFees.set(asset, newAmount.intoUint256());
    }

    /// @notice Support function to increment the collected fees
    /// @param self The fee storage pointer
    /// @param amountX18 The amount to be incremented
    function incrementCollectedFees(Data storage self, UD60x18 amountX18) internal {
        UD60x18 newAmount = amountX18.add(ud60x18(self.collectedFees));

        self.collectedFees = newAmount.intoUint256();
    }

    /// @notice Support function to decrease the collected fees
    /// @param self The fee storage pointer
    /// @param amountX18 The amount to be incremented
    function decrementCollectedFees(Data storage self, UD60x18 amountX18) internal {
        UD60x18 newAmount = amountX18.sub(ud60x18(self.collectedFees));

        self.collectedFees = newAmount.intoUint256();
    }
}
