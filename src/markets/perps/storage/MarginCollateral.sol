// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";

library MarginCollateral {
    /// @notice Thrown when `collateralType` doesn't have a price feed defined to return its price.
    error CollateralPriceFeedNotDefined(address collateralType);

    /// @notice Constant base domain used to access a given MarginCollateral's storage slot.
    string internal constant MARGIN_COLLATERAL_DOMAIN = "fi.zaros.markets.MarginCollateral";

    /// @notice {MarginCollateral} namespace storage structure.
    /// @param depositCap The maximum deposit cap of the given margin collateral type
    /// @param decimals The decimals of the given margin collateral type's ERC20 token
    /// @param priceFeed The chainlink price feed address of the given margin collateral type
    struct Data {
        uint248 depositCap;
        uint8 decimals;
        address priceFeed;
    }

    /// @notice Loads a {MarginCollateral} object.
    /// @param collateralType The margin collateral type.
    /// @return marginCollateral The loaded margin collateral storage pointer.
    function load(address collateralType) internal pure returns (Data storage marginCollateral) {
        bytes32 slot = keccak256(abi.encode(MARGIN_COLLATERAL_DOMAIN, collateralType));
        assembly {
            marginCollateral.slot := slot
        }
    }

    /// @notice Returns the maximum amount that can be deposited as margin.
    /// @param self The margin collateral type storage pointer.
    /// @return depositCap The configured deposit cap for the given collateral type.
    function getDepositCap(Data storage self) internal view returns (UD60x18 depositCap) {
        depositCap = ud60x18(self.depositCap);
    }

    /// @notice Updates the deposit cap of a given collateral type. If zero, it is considered
    /// disabled.
    /// @dev If the collateral is enabled, a price feed must be set.
    /// @param self The margin collateral type storage pointer.
    /// @param depositCap The maximum amount of collateral that can be deposited.
    function setDepositCap(Data storage self, uint248 depositCap) internal {
        self.depositCap = depositCap;
    }

    /// @notice Configures the Chainlink Price Feed address of the given margin collateral type.
    /// @param self The margin collateral type storage pointer.
    /// @param priceFeed The Chainlink Price Feed address.
    function configurePriceFeed(Data storage self, address priceFeed) internal {
        self.priceFeed = priceFeed;
    }

    /// @notice Returns the price of the given margin collateral type.
    /// @param self The margin collateral type storage pointer.
    /// @return price The price of the given margin collateral type.
    function getCollateralPrice(Data storage self) internal view returns (UD60x18 price) {
        address priceFeed = self.priceFeed;
        if (priceFeed == address(0)) {
            revert CollateralPriceFeedNotDefined(collateralType);
        }

        price = getPrice(self, IAggregatorV3(priceFeed));
    }

    /// @notice Queries the Chainlink Price Feed for the margin collateral oracle price.
    /// @param self The margin collateral type storage pointer.
    /// @param priceFeed The Chainlink Price Feed address.
    /// @return price The parsed price of the given margin collateral type.
    function getPrice(Data storage self, IAggregatorV3 priceFeed) internal view returns (UD60x18 price) {
        uint8 priceDecimals = priceFeed.decimals();
        (, int256 answer,,,) = priceFeed.latestRoundData();

        // should panic if decimals > 18
        assert(decimals <= Constants.SYSTEM_DECIMALS);
        price = ud60x18(answer.toUint256() * 10 ** (Constants.SYSTEM_DECIMALS - decimals));
    }
}
