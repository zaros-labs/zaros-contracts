// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Math } from "@zaros/utils/Math.sol";
import { IPriceAdapter } from "@zaros/utils/PriceAdapter.sol";
import { MarketMakingEngineConfiguration } from "@zaros/market-making/leaves/MarketMakingEngineConfiguration.sol";

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";

library Collateral {
    /// @notice ERC7201 storage location.
    bytes32 internal constant COLLATERAL_LOCATION =
        keccak256(abi.encode(uint256(keccak256("fi.zaros.market-making.Collateral")) - 1));

    // TODO: pack storage slots
    struct Data {
        uint256 creditRatio;
        bool isEnabled;
        uint8 decimals;
        address priceAdapter;
        address asset;
    }

    /// @notice Loads a {Collateral}.
    /// @param asset The collateral asset address.
    /// @return collateral The loaded collateral storage pointer.
    function load(address asset) internal pure returns (Data storage collateral) {
        bytes32 slot = keccak256(abi.encode(COLLATERAL_LOCATION, asset));
        assembly {
            collateral.slot := slot
        }
    }

    /// @notice Reverts if the provided {Collateral} isn't enabled by the system.
    /// @param self The {Collateral} storage pointer.
    function verifyIsEnabled(Data storage self) internal view {
        if (!self.isEnabled) {
            revert Errors.CollateralDisabled(self.asset);
        }
    }

    /// @notice Converts the provided denormalized amount of collateral to UD60x18.
    /// @dev We can assume self.decimals is always <= SYSTEM_DECIMALS, since it's a requirement at `setDecimals`.
    /// @param self The collateral type storage pointer.
    /// @param amount The amount of collateral to convert.
    /// @return amountX18 The converted amount of collateral to the system's decimals.
    function convertTokenAmountToUd60x18(Data storage self, uint256 amount) internal view returns (UD60x18) {
        return Math.convertTokenAmountToUd60x18(self.decimals, amount);
    }

    /// @notice Converts the provided 18 decimals normalized amount to the collateral's decimals amount.
    /// @dev We can assume self.decimals is always <= SYSTEM_DECIMALS, since it's a requirement at `setDecimals`.
    /// @param self The collateral type storage pointer.
    /// @param amountX18 The 18 decimals normalized amount.
    /// @return amount The denormalized amount using the ERC20 token's decimals.
    function convertUd60x18ToTokenAmount(
        Data storage self,
        UD60x18 amountX18
    )
        internal
        view
        returns (uint256 amount)
    {
        return Math.convertUd60x18ToTokenAmount(self.decimals, amountX18);
    }

    function getPrice(Data storage self) internal view returns (UD60x18 priceX18) {
        address priceAdapter = self.priceAdapter;

        if (priceAdapter == address(0)) {
            revert Errors.CollateralPriceFeedNotDefined();
        }

        priceX18 = IPriceAdapter(priceAdapter).getPrice();
    }
}
