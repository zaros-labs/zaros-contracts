// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { MarketMakingEngineConfiguration } from "@zaros/market-making/leaves/MarketMakingEngineConfiguration.sol";

contract MarketMakingEngineConfigurationHarness {
    function workaround_setWethAddress(address wethAddr) external returns (address) {
        MarketMakingEngineConfiguration.Data storage data = MarketMakingEngineConfiguration.load();
        data.weth = wethAddr;
        return data.weth;
    }

    function workaround_setPerpsEngineAddress(address perpsEngineAddr) external  {
        // MarketMakingEngineConfiguration.Data storage data = MarketMakingEngineConfiguration.load();
        // data.perpsEngine = perpsEngineAddr;
        // return data.perpsEngine;
    }

    function workaround_setFeeRecipients(address[] calldata feeRecipients) external {
        // MarketMakingEngineConfiguration.Data storage data = MarketMakingEngineConfiguration.load();
        // data.feeRecipients.push(feeRecipients);
    }
}
