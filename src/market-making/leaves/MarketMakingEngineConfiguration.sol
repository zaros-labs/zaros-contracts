// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// PRB Math dependencies
import { UD60x18, ud60x18, ZERO as UD60x18_ZERO } from "@prb-math/UD60x18.sol";

// Open Zeppelin dependencies
import { IERC20, SafeERC20 } from "@openzeppelin/token/ERC20/extensions/ERC4626.sol";
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { EnumerableMap } from "@openzeppelin/utils/structs/EnumerableMap.sol";

library MarketMakingEngineConfiguration {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    /// @notice ERC7201 storage location.
    bytes32 internal constant MARKET_MAKING_ENGINE_CONFIGURATION_LOCATION =
        keccak256(abi.encode(uint256(keccak256("fi.zaros.market-making.MarketMakingEngineConfiguration")) - 1));

    // TODO: pack storage slots
    struct Data {
        address usdc;
        address weth;
        address feeDistributor;
        EnumerableMap.AddressToUintMap protocolFeeRecipients;
        mapping(address engine => bool isRegistered) isRegisteredEngine;
        mapping(address engine => address usdToken) usdTokenOfEngine;
        // TODO: define roles
        mapping(address keeper => bool isEnabled) isSystemKeeperEnabled;
    }

    /// @notice Loads the {MarketMakingEngineConfiguration} namespace.
    /// @return marketMakingEngineConfiguration The loaded market making engine configuration storage pointer.
    function load() internal pure returns (Data storage marketMakingEngineConfiguration) {
        bytes32 slot = MARKET_MAKING_ENGINE_CONFIGURATION_LOCATION;
        assembly {
            marketMakingEngineConfiguration.slot := slot
        }
    }

    /// @notice calculate the total fee recipients shares
    /// @param self The {MarketMakingEngineConfiguration} storage pointer.
    /// @return totalFeeRecipientsSharesX18 The total fee recipients shares.
    function getTotalFeeRecipientsShares(Data storage self)
        internal
        view
        returns (UD60x18 totalFeeRecipientsSharesX18)
    {
        // Initialize the total fee recipients shares to zero.
        totalFeeRecipientsSharesX18 = UD60x18_ZERO;

        // Cache the length of the protocol fee recipients
        uint256 feeRecipientsLength = self.protocolFeeRecipients.length();

        // Iterate over the protocol fee recipients
        for (uint256 i = 0; i < feeRecipientsLength; i++) {
            // Load the shares of the fee recipient
            (, uint256 shares) = self.protocolFeeRecipients.at(i);

            // Add the shares to the total fee recipients shares
            totalFeeRecipientsSharesX18 = totalFeeRecipientsSharesX18.add(ud60x18(shares));
        }
    }

    /// @notice Sends the accumulated protocol WETH reward to the configured recipients.
    /// @param self The {MarketMakingEngineConfiguration} storage pointer.
    /// @param wethReward The accumulated WETH reward to distribute.
    function distributeProtocolWethReward(Data storage self, uint256 wethReward) internal {
        // Cache the length of the protocol fee recipients
        uint256 feeRecipientsLength = self.protocolFeeRecipients.length();

        // Iterate over the protocol fee recipients
        for (uint256 i; i < feeRecipientsLength; i++) {
            // Load the fee recipient address and shares
            (address feeRecipient, uint256 shares) = self.protocolFeeRecipients.at(i);

            // Calculate the fee recipient reward
            uint256 feeRecipientWethReward =
                ud60x18(wethReward).mul(ud60x18(shares).div(getTotalFeeRecipientsShares(self))).intoUint256();

            // Transfer the fee recipient reward
            IERC20(self.weth).safeTransfer(feeRecipient, feeRecipientWethReward);
        }
    }
}
