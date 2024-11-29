// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";

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
        address referralModule;
        uint128 settlementBaseFeeUsdX18;
        uint128 totalFeeRecipientsShares;
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

    /// @notice Sends the accumulated protocol reward to the configured recipients using the given asset.
    /// @param self The {MarketMakingEngineConfiguration} storage pointer.
    /// @param asset The asset to be distributed as reward.
    /// @param amount The accumulated reward amount.
    function distributeProtocolAssetReward(Data storage self, address asset, uint256 amount) internal {
        // cache the length of the protocol fee recipients
        uint256 feeRecipientsLength = self.protocolFeeRecipients.length();

        // iterate over the protocol configured fee recipients
        for (uint256 i; i < feeRecipientsLength; i++) {
            // load the fee recipient address and shares
            (address feeRecipient, uint256 shares) = self.protocolFeeRecipients.at(i);

            // Calculate the fee recipient reward
            uint256 feeRecipientReward =
                ud60x18(amount).mul(ud60x18(shares).div(ud60x18(self.totalFeeRecipientsShares))).intoUint256();

            // Transfer the fee recipient reward
            IERC20(asset).safeTransfer(feeRecipient, feeRecipientReward);
        }
    }
}
