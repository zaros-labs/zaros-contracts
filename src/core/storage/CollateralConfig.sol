//SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

// Zaros dependencies
import { Constants } from "@zaros/utils/Constants.sol";
import { IAggregatorV3 } from "@zaros/external/interfaces/chainlink/IAggregatorV3.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18, ZERO as UD_ZERO } from "@prb-math/UD60x18.sol";

/**
 * @title Tracks system-wide settings for each collateral type, as well as helper functions for it, such as retrieving
 * its current price from the oracle manager.
 */
library CollateralConfig {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeCast for int256;

    string internal constant COLLATERAL_CONFIG_DOMAIN = "fi.zaros.core.CollateralConfig";
    bytes32 internal constant SLOT_AVAILABLE_COLLATERALS =
        keccak256(abi.encode(COLLATERAL_CONFIG_DOMAIN, "_availableCollaterals"));

    /**
     * @dev Thrown when the token address of a collateral cannot be found.
     */
    error Zaros_CollateralConfig_CollateralNotFound();

    /**
     * @dev Thrown when deposits are disabled for the given collateral type.
     * @param collateralType The address of the collateral type for which depositing was disabled.
     */
    error Zaros_CollateralConfig_CollateralDepositDisabled(address collateralType);

    /**
     * @dev Thrown when collateral ratio is not sufficient in a given operation in the system.
     * @param collateralValue The net USD value of the position.
     * @param debt The net USD debt of the position.
     * @param ratio The collateralization ratio of the position.
     * @param minRatio The minimum c-ratio which was not met. Could be issuance ratio or liquidation ratio, depending on
     * the case.
     */
    error Zaros_CollateralConfig_InsufficientCollateralRatio(
        uint256 collateralValue, uint256 debt, uint256 ratio, uint256 minRatio
    );

    /**
     * @dev Thrown when the amount being delegated is less than the minimum expected amount.
     * @param minDelegation The current minimum for deposits and delegation set to this collateral type.
     */
    error Zaros_CollateralConfig_InsufficientDelegation(uint256 minDelegation);

    /**
     * @dev Thrown when attempting to convert a token to the system amount and the conversion results in a loss of
     * precision.
     * @param tokenAmount The amount of tokens that were attempted to be converted.
     * @param decimals The number of decimals of the token that was attempted to be converted.
     */
    error Zaros_CollateralConfig_PrecisionLost(uint256 tokenAmount, uint8 decimals);

    struct Data {
        bool depositingEnabled;
        uint256 issuanceRatio;
        uint256 liquidationRatio;
        uint256 liquidationRewardRatio;
        address oracle;
        address tokenAddress;
        uint8 decimals;
        /// @dev Minimum amount of collateral that can be delegated to the market manager
        uint256 minDelegation;
    }

    /**
     * @dev Loads the CollateralConfig object for the given collateralType collateral.
     * @param token The address of the collateralType collateral.
     * @return collateralConfig The CollateralConfig object.
     */
    function load(address token) internal pure returns (Data storage collateralConfig) {
        bytes32 s = keccak256(abi.encode(COLLATERAL_CONFIG_DOMAIN, token));
        assembly {
            collateralConfig.slot := s
        }
    }

    function loadAvailableCollaterals() internal pure returns (EnumerableSet.AddressSet storage availableCollaterals) {
        bytes32 s = SLOT_AVAILABLE_COLLATERALS;
        assembly {
            availableCollaterals.slot := s
        }
    }

    function set(Data memory config) internal {
        EnumerableSet.AddressSet storage collateralTypes = loadAvailableCollaterals();

        if (!collateralTypes.contains(config.tokenAddress)) {
            collateralTypes.add(config.tokenAddress);
        }

        Data storage storedConfig = load(config.tokenAddress);

        storedConfig.tokenAddress = config.tokenAddress;
        storedConfig.decimals = config.decimals;
        storedConfig.issuanceRatio = config.issuanceRatio;
        storedConfig.liquidationRatio = config.liquidationRatio;
        storedConfig.oracle = config.oracle;
        storedConfig.liquidationRewardRatio = config.liquidationRewardRatio;
        storedConfig.minDelegation = config.minDelegation;
        storedConfig.depositingEnabled = config.depositingEnabled;
    }

    /**
     * @dev Shows if a given collateral type is enabled for deposits and delegation.
     * @param token The address of the collateral being queried.
     */
    function collateralEnabled(address token) internal view {
        if (!load(token).depositingEnabled) {
            revert Zaros_CollateralConfig_CollateralDepositDisabled(token);
        }
    }

    /**
     * @dev Reverts if the amount being delegated is insufficient for the system.
     * @param token The address of the collateral type.
     * @param amount The amount being checked for sufficient delegation.
     */
    function requireSufficientDelegation(address token, UD60x18 amount) internal view {
        CollateralConfig.Data storage config = load(token);

        UD60x18 minDelegation = ud60x18(config.minDelegation);

        if (amount.lt(minDelegation)) {
            revert Zaros_CollateralConfig_InsufficientDelegation(minDelegation.intoUint256());
        }
    }

    /// TODO: improve this
    function getCollateralPrice(Data storage self) internal view returns (UD60x18) {
        IAggregatorV3 oracle = IAggregatorV3(self.oracle);
        uint8 decimals = oracle.decimals();
        (, int256 answer,,,) = oracle.latestRoundData();

        // should panic if decimals > 18
        assert(decimals <= Constants.DECIMALS);
        UD60x18 price = ud60x18(answer.toUint256() * 10 ** (Constants.DECIMALS - decimals));

        return price;
    }

    /**
     * @dev Reverts if the specified collateral and debt values produce a collateralization ratio which is below the
     * amount required for new issuance of zrsUSD.
     * @param self The CollateralConfig object whose collateral and settings are being queried.
     * @param debt The debt component of the ratio.
     * @param collateralValue The collateral component of the ratio.
     */
    function verifyIssuanceRatio(Data storage self, UD60x18 debt, UD60x18 collateralValue) internal view {
        if (
            debt.neq(UD_ZERO)
                && (collateralValue.eq(UD_ZERO) || collateralValue.div(debt).lt(ud60x18(self.issuanceRatio)))
        ) {
            revert Zaros_CollateralConfig_InsufficientCollateralRatio(
                collateralValue.intoUint256(),
                debt.intoUint256(),
                collateralValue.div(debt).intoUint256(),
                self.issuanceRatio
            );
        }
    }

    /**
     * @dev Converts token amounts with non-system decimal precisions, to 18 decimals of precision.
     * E.g: $TOKEN_A uses 6 decimals of precision, so this would upscale it by 12 decimals.
     * E.g: $TOKEN_B uses 20 decimals of precision, so this would downscale it by 2 decimals.
     * @param self The CollateralConfig object corresponding to the collateral type being converted.
     * @param tokenAmount The token amount, denominated in its native decimal precision.
     * @return wad The converted amount, denominated in the system's 18 decimal precision.
     */
    function normalizeTokenAmount(Data storage self, uint256 tokenAmount) internal view returns (UD60x18 wad) {
        if (self.tokenAddress == address(0)) {
            revert Zaros_CollateralConfig_CollateralNotFound();
        }

        if (self.decimals == Constants.DECIMALS) {
            wad = ud60x18(tokenAmount);
        } else if (self.decimals < Constants.DECIMALS) {
            uint256 scalar;
            unchecked {
                scalar = Constants.DECIMALS - self.decimals;
            }
            wad = ud60x18(tokenAmount * scalar);
        }
    }
}
