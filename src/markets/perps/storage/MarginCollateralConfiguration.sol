// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { IAggregatorV3 } from "@zaros/external/chainlink/interfaces/IAggregatorV3.sol";
import { Constants } from "@zaros/utils/Constants.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { OracleUtil } from "@zaros/utils/OracleUtil.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

library MarginCollateralConfiguration {
    /// @notice Constant base domain used to access a given MarginCollateralConfiguration's storage slot.
    string internal constant MARGIN_COLLATERAL_CONFIGURATION_DOMAIN = "fi.zaros.markets.MarginCollateralConfiguration";

    /// @notice {MarginCollateralConfiguration} namespace storage structure.
    /// @param depositCap The maximum deposit cap of the given margin collateral type.
    /// @param loanToValue The value used to calculate the effective margin balance of a given collateral type.
    /// @param decimals The decimals of the given margin collateral type's ERC20 token.
    /// @param priceFeed The chainlink price feed address of the given margin collateral type.
    struct Data {
        uint128 depositCap;
        uint120 loanToValue;
        uint8 decimals;
        address priceFeed;
    }

    /// @notice Loads a {MarginCollateralConfiguration} object.
    /// @param collateralType The margin collateral type.
    /// @return marginCollateralConfiguration The loaded margin collateral storage pointer.
    function load(address collateralType) internal pure returns (Data storage marginCollateralConfiguration) {
        bytes32 slot = keccak256(abi.encode(MARGIN_COLLATERAL_CONFIGURATION_DOMAIN, collateralType));
        assembly {
            marginCollateralConfiguration.slot := slot
        }
    }

    /// @notice Converts the provided denormalized amount of margin collateral to UD60x18.
    /// @dev We can assume self.decimals is always <= SYSTEM_DECIMALS, since it's a requirement at `setDecimals`.
    /// @param self The margin collateral type storage pointer.
    /// @param amount The amount of margin collateral to convert.
    /// @return systemAmount The converted amount of margin collateral to the system's decimals.
    function convertTokenAmountToUd60x18(Data storage self, uint256 amount) internal view returns (UD60x18) {
        if (Constants.SYSTEM_DECIMALS == self.decimals) {
            return ud60x18(amount);
        }
        return ud60x18(amount * 10 ** (Constants.SYSTEM_DECIMALS - self.decimals));
    }

    function convertUd60x18ToTokenAmount(Data storage self, UD60x18 ud60x18Amount) internal view returns (uint256) {
        if (Constants.SYSTEM_DECIMALS == self.decimals) {
            return ud60x18Amount.intoUint256();
        }

        return ud60x18Amount.intoUint256() / (10 ** (Constants.SYSTEM_DECIMALS - self.decimals));
    }

    /// @notice Configures the settings of a given margin collateral type.
    /// @dev A margin collateral type is considered disabled if `depositCap` == 0.
    /// @param collateralType The address of the collateral type.
    /// @param depositCap The maximum amount of  collateral that can be deposited.
    /// @param loanToValue The value used to calculate the effective margin balance of a given collateral type.
    /// @param decimals The amount of decimals of the given margin collateral type's ERC20 token.
    /// @param priceFeed The price oracle address.
    function configure(
        address collateralType,
        uint128 depositCap,
        uint120 loanToValue,
        uint8 decimals,
        address priceFeed
    )
        internal
    {
        Data storage self = load(collateralType);

        self.depositCap = depositCap;
        self.loanToValue = loanToValue;
        self.decimals = decimals;
        self.priceFeed = priceFeed;
    }

    /// @notice Returns the price of the given margin collateral type.
    /// @param self The margin collateral type storage pointer.
    /// @return price The price of the given margin collateral type.
    function getPrice(Data storage self) internal view returns (UD60x18 price) {
        address priceFeed = self.priceFeed;
        if (priceFeed == address(0)) {
            revert Errors.CollateralPriceFeedNotDefined();
        }

        price = OracleUtil.getPrice(IAggregatorV3(priceFeed));
    }
}
