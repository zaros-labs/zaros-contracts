// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { PerpsEngine } from "@zaros/markets/perps/PerpsEngine.sol";
import { OrderFees } from "@zaros/markets/perps/storage/OrderFees.sol";
import { BaseScript } from "./Base.s.sol";

contract CreatePerpsMarket is BaseScript {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/
    bytes32 internal ethUsdStreamId;
    address internal ethUsdPriceFeed;

    uint128 internal constant ETH_USD_MARKET_ID = 1;
    string internal constant ETH_USD_MARKET_NAME = "ETH/USD Perpetual Futures";
    string internal constant ETH_USD_MARKET_SYMBOL = "ETH/USD PERP";
    uint128 internal constant ETH_USD_MMR = 0.01e18;
    uint128 internal constant ETH_USD_MAX_OI = 100_000_000e18;
    uint128 internal constant ETH_USD_MIN_IMR = 0.01e18;
    OrderFees.Data internal ethUsdOrderFee = OrderFees.Data({ makerFee: 0.04e18, takerFee: 0.08e18 });

    bytes32 internal linkUsdStreamId;
    address internal linkUsdPriceFeed;

    uint128 internal constant LINK_USD_MARKET_ID = 2;
    string internal constant LINK_USD_MARKET_NAME = "LINK/USD Perpetual";
    string internal constant LINK_USD_MARKET_SYMBOL = "LINK/USD-PERP";
    uint128 internal constant LINK_USD_MMR = 0.01e18;
    uint128 internal constant LINK_USD_MAX_OI = 100_000_000e18;
    uint128 internal constant LINK_USD_MIN_IMR = 0.01e18;
    OrderFees.Data internal linkUsdOrderFee = OrderFees.Data({ makerFee: 0.04e18, takerFee: 0.08e18 });

    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/
    PerpsEngine internal perpsEngine;

    function run() public broadcaster {
        ethUsdStreamId = vm.envBytes32("ETH_USD_STREAM_ID");
        ethUsdPriceFeed = vm.envAddress("ETH_USD_PRICE_FEED");

        linkUsdStreamId = vm.envBytes32("LINK_USD_STREAM_ID");
        linkUsdPriceFeed = vm.envAddress("LINK_USD_PRICE_FEED");

        perpsEngine = PerpsEngine(payable(address(vm.envAddress("PERPS_ENGINE"))));

        perpsEngine.createPerpsMarket(
            ETH_USD_MARKET_ID,
            ETH_USD_MARKET_NAME,
            ETH_USD_MARKET_SYMBOL,
            ethUsdStreamId,
            ethUsdPriceFeed,
            ETH_USD_MMR,
            ETH_USD_MAX_OI,
            ETH_USD_MIN_IMR,
            ethUsdOrderFee
        );

        perpsEngine.createPerpsMarket(
            LINK_USD_MARKET_ID,
            LINK_USD_MARKET_NAME,
            LINK_USD_MARKET_SYMBOL,
            linkUsdStreamId,
            linkUsdPriceFeed,
            LINK_USD_MMR,
            LINK_USD_MAX_OI,
            LINK_USD_MIN_IMR,
            linkUsdOrderFee
        );
    }
}
