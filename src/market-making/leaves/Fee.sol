// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { FeeRecipient } from "../leaves/FeeRecipient.sol";

library Fee {
    /// @notice ERC7201 storage location.
    bytes32 internal constant FEE_LOCATION =
        keccak256(abi.encode(uint256(keccak256("fi.zaros.market-making.Fee")) - 1));


    uint256 internal constant TOTAL_FEE_SHARES = 10_000;

    /// @param feeAssets collection of token addresses for the received fees
    /// @param accumulatedWeth total collected fee from tokens in WETH
    /// @param recipientsFeeUnsettled total fees available for fee recipients
    /// @param rewardDistributorUnsettled total fees available for fee distributor contract
    /// @param feeAmounts total fee amount collected per collateral
    struct Data {
        address[] feeAssets;
        uint256 recipientsFeeUnsettled;
        uint256 rewardDistributorUnsettled;
        mapping(address collateralType => uint256 amount) feeAmounts;
    }

    /// @notice Loads a { Fee }.
    /// @return fee The loaded fee storage pointer.
    function load() internal pure returns (Data storage fee) {
        bytes32 slot = keccak256(abi.encode(FEE_LOCATION));
        assembly {
            fee.slot := slot
        }
    }
}
