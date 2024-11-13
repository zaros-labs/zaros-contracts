// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// PRB Math dependencies
import { ud60x18 } from "@prb-math/UD60x18.sol";

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

    /// @notice The storage structure for the {MarketMakingEngineConfiguration} namespace.
    /// @param depositFee The despoit fee in the Vault, example 1e18 (100%), 1e17 (10%), 1e16 (1%), 1e15 (0,1%).
    /// @param redeemFee The redeem fee in the Vault, example 1e18 (100%), 1e17 (10%), 1e16 (1%), 1e15 (0,1%).
    /// @param usdc The USDC token address.
    /// @param weth The WETH token address.
    /// @param feeDistributor The fee distributor address.
    /// @param referralModule The referral module address.
    /// @param vaultDepositAndRedeemFeeRecipient The vault collaterals fee recipient address.
    /// @param protocolFeeRecipients The protocol fee recipients.
    /// @param isRegisteredEngine The mapping of registered engines.
    /// @param usdTokenOfEngine The mapping of USD tokens of engines.
    /// @param isSystemKeeperEnabled The mapping of system keepers.
    struct Data {
        uint256 depositFee;
        uint256 redeemFee;
        address usdc;
        address weth;
        address feeDistributor;
        address referralModule;
        uint128 settlementBaseFeeUsdX18;
        uint128 totalFeeRecipientsShares;
        address vaultDepositAndredeemFeeRecipient;
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
