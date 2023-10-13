// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { PerpsEngine } from "@zaros/markets/perps/PerpsEngine.sol";
import { OrderFees } from "@zaros/markets/perps/storage/OrderFees.sol";
import { BaseScript } from "./Base.s.sol";

contract DeployAlphaPerps is BaseScript {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/
    bytes32 internal streamId;
    address internal priceFeed;

    uint128 internal constant MARKET_ID = 2;
    string internal constant MARKET_NAME = "LINK/USD Perpetual";
    string internal constant MARKET_SYMBOL = "LINK/USD-PERP";
    uint128 internal constant MARKET_MMR = 0.01e18;
    uint128 internal constant MARKET_MAX_OI = 100_000_000e18;
    uint128 internal constant MARKET_MIN_IMR = 0.01e18;
    OrderFees.Data public orderFees = OrderFees.Data({ makerFee: 0.04e18, takerFee: 0.08e18 });

    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/
    PerpsEngine internal perpsEngine;

    function run() public broadcaster {
        streamId = vm.envBytes32("LINK_USD_STREAM_ID");
        priceFeed = vm.envAddress("LINK_USD_PRICE_FEED");

        perpsEngine = PerpsEngine(payable(address(vm.envAddress("PERPS_ENGINE"))));

        perpsEngine.createPerpsMarket(
            MARKET_ID,
            MARKET_NAME,
            MARKET_SYMBOL,
            streamId,
            priceFeed,
            MARKET_MMR,
            MARKET_MAX_OI,
            MARKET_MIN_IMR,
            orderFees
        );
    }
}
