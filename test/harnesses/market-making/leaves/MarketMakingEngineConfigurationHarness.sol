// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { MarketMakingEngineConfiguration } from "@zaros/market-making/leaves/MarketMakingEngineConfiguration.sol";

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";

contract MarketMakingEngineConfigurationHarness {
    function workaround_setWethAddress(address wethAddr) external returns (address) {
        MarketMakingEngineConfiguration.Data storage data = MarketMakingEngineConfiguration.load();
        data.weth = wethAddr;
        return data.weth;
    }

    function exposed_getTotalFeeRecipientsShares() external view returns (UD60x18) {
        MarketMakingEngineConfiguration.Data storage self = MarketMakingEngineConfiguration.load();
        return MarketMakingEngineConfiguration.getTotalFeeRecipientsShares(self);
    }
}
