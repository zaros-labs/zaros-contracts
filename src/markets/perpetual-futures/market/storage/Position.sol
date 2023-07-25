//SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { PerpsMarketConfig } from "./PerpsMarketConfig.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

library Position {
    using PerpsMarketConfig for PerpsMarketConfig.Data;

    struct Margin {
        address collateralType;
        uint256 amount;
    }

    struct Data {
        Margin margin;
        int256 size;
        uint256 lastInteractionPrice;
        int256 lastInteractionFunding;
    }

    function updatePosition(Data storage self, Data memory newPosition) internal {
        self.margin = newPosition.margin;
        self.size = newPosition.size;
        self.lastInteractionPrice = newPosition.lastInteractionPrice;
        self.lastInteractionFunding = newPosition.lastInteractionFunding;
    }

    function clear(Data storage self) internal {
        self.size = 0;
        self.lastInteractionPrice = 0;
        self.lastInteractionFunding = 0;
    }

    function getPositionData(
        Data storage self,
        UD60x18 price
    )
        internal
        view
        returns (
            UD60x18 notionalValue,
            SD59x18 size,
            SD59x18 pnl,
            SD59x18 accruedFunding,
            SD59x18 netFundingPerUnit,
            SD59x18 nextFunding
        )
    {
        (pnl, accruedFunding, netFundingPerUnit, nextFunding) = getPnl(self, price);
        size = sd59x18(self.size);
        notionalValue = getNotionalValue(self, price);
    }

    function getPnl(
        Data storage self,
        UD60x18 price
    )
        internal
        view
        returns (SD59x18 pnl, SD59x18 accruedFunding, SD59x18 netFundingPerUnit, SD59x18 nextFunding)
    {
        nextFunding = PerpsMarketConfig.load().calculateNextFunding(price);
        netFundingPerUnit = nextFunding.sub(sd59x18(self.lastInteractionFunding));
        accruedFunding = sd59x18(self.size).mul(netFundingPerUnit);

        SD59x18 priceShift = price.intoSD59x18().sub(ud60x18(self.lastInteractionPrice).intoSD59x18());
        pnl = sd59x18(self.size).mul(priceShift).add(accruedFunding);
    }

    function getNotionalValue(Data storage self, UD60x18 price) internal view returns (UD60x18) {
        return sd59x18(self.size).abs().intoUD60x18().mul(price);
    }
}
