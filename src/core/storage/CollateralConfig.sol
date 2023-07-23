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

    error Zaros_CollateralConfig_CollateralNotFound();

    error Zaros_CollateralConfig_CollateralDepositDisabled(address collateralType);

    error Zaros_CollateralConfig_InsufficientCollateralRatio(
        uint256 collateralValue, uint256 debt, uint256 ratio, uint256 minRatio
    );

    error Zaros_CollateralConfig_InsufficientDelegation(uint256 minDelegation);

    error Zaros_CollateralConfig_PrecisionLost(uint256 tokenAmount, uint8 decimals);

    struct Data {
        bool depositingEnabled;
        uint80 issuanceRatio;
        uint80 liquidationRatio;
        uint80 liquidationRewardRatio;
        uint8 decimals;
        address oracle;
        address tokenAddress;
        /// @dev Minimum amount of collateral that can be delegated to the market manager
        uint256 minDelegation;
        uint256 depositCap;
    }

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

        storedConfig.depositingEnabled = config.depositingEnabled;
        storedConfig.issuanceRatio = config.issuanceRatio;
        storedConfig.liquidationRatio = config.liquidationRatio;
        storedConfig.liquidationRewardRatio = config.liquidationRewardRatio;
        storedConfig.decimals = config.decimals;
        storedConfig.oracle = config.oracle;
        storedConfig.tokenAddress = config.tokenAddress;
        storedConfig.minDelegation = config.minDelegation;
    }

    function collateralEnabled(address token) internal view {
        if (!load(token).depositingEnabled) {
            revert Zaros_CollateralConfig_CollateralDepositDisabled(token);
        }
    }

    function requireSufficientDelegation(address token, UD60x18 amount) internal view {
        CollateralConfig.Data storage config = load(token);

        UD60x18 minDelegation = ud60x18(config.minDelegation);

        if (amount.lt(minDelegation)) {
            revert Zaros_CollateralConfig_InsufficientDelegation(minDelegation.intoUint256());
        }
    }

    /// @dev TODO: improve this
    function getCollateralPrice(Data storage self) internal view returns (UD60x18) {
        IAggregatorV3 oracle = IAggregatorV3(self.oracle);
        uint8 decimals = oracle.decimals();
        (, int256 answer,,,) = oracle.latestRoundData();

        // should panic if decimals > 18
        assert(decimals <= Constants.DECIMALS);
        UD60x18 price = ud60x18(answer.toUint256() * 10 ** (Constants.DECIMALS - decimals));

        return price;
    }

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
