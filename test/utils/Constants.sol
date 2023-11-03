// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

// Zaros dependencies
import { Constants as ProtocolConstants } from "@zaros/utils/Constants.sol";

// PRB Math dependencies
import { uMAX_UD60x18 as LIB_uMAX_UD60x18 } from "@prb-math/UD60x18.sol";
import { uMAX_SD59x18 as LIB_uMAX_SD59x18, uMIN_SD59x18 as LIB_uMIN_SD59x18 } from "@prb-math/SD59x18.sol";

abstract contract Constants {
    /// @notice The maximum value that can be represented in a UD60x18.
    uint256 internal constant uMAX_UD60x18 = LIB_uMAX_UD60x18;

    /// @notice The maximum value that can be represented in a SD59x18.
    int256 internal constant uMAX_SD59x18x18 = LIB_uMAX_SD59x18;

    /// @notice The minimum value that can be represented in a SD59x18.
    int256 internal constant uMIN_SD59x18 = LIB_uMIN_SD59x18;

    /// @notice The default decimals value used in the protocol.
    uint8 internal constant DEFAULT_DECIMALS = ProtocolConstants.DECIMALS;

    /// @notice Feature flags for all permissionless features.
    bytes32 internal constant CREATE_ACCOUNT_FEATURE_FLAG = ProtocolConstants.CREATE_ACCOUNT_FEATURE_FLAG;
    bytes32 internal constant DEPOSIT_FEATURE_FLAG = ProtocolConstants.DEPOSIT_FEATURE_FLAG;
    bytes32 internal constant WITHDRAW_FEATURE_FLAG = ProtocolConstants.WITHDRAW_FEATURE_FLAG;
    bytes32 internal constant CLAIM_FEATURE_FLAG = ProtocolConstants.CLAIM_FEATURE_FLAG;
    bytes32 internal constant DELEGATE_FEATURE_FLAG = ProtocolConstants.DELEGATE_FEATURE_FLAG;

    /// @notice Zaros USD permissioned features.
    bytes32 internal constant BURN_FEATURE_FLAG = ProtocolConstants.BURN_FEATURE_FLAG;
    bytes32 internal constant MINT_FEATURE_FLAG = ProtocolConstants.MINT_FEATURE_FLAG;
}
