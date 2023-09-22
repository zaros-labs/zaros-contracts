// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

//       __________  _____ __________ ________    _________
//       \____    / /  _  \\______   \\_____  \  /   _____/
//         /     / /  /_\  \|       _/ /   |   \ \_____  \
//        /     /_/    |    \    |   \/    |    \/        \
//  _____/_______ \____|__  /____|_  /\_______  /_______  /_____
// /_____/       \/       \/       \/         \/        \/_____/

// Zaros dependencies
import { AccountNFT } from "@zaros/account-nft/AccountNFT.sol";
import { PerpsEngine } from "@zaros/markets/perps/PerpsEngine.sol";
import { OrderFees } from "@zaros/markets/perps/storage/OrderFees.sol";
import { ZarosUSD } from "@zaros/usd/ZarosUSD.sol";
import { BaseScript } from "./Base.s.sol";

// Forge dependencies
import "forge-std/console.sol";

contract DeployAlphaPerps is BaseScript {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/
    address internal mockChainlinkVerifier = address(1);
    address internal mockRewardDistributorAddress = address(2);
    address internal mockZarosAddress = address(3);
    bytes32 internal ethUsdStreamId;
    address internal ethUsdPriceFeed;

    uint128 internal constant ETH_USD_MARKET_ID = 1;
    string internal constant ETH_USD_MARKET_NAME = "ETH/USD Perpetual Futures";
    string internal constant ETH_USD_MARKET_SYMBOL = "ETH/USD PERP";
    uint128 internal constant ETH_USD_MMR = 0.01e18;
    uint128 internal constant ETH_USD_MAX_OI = 100_000_000e18;
    uint128 internal constant ETH_USD_MIN_IMR = 0.01e18;
    OrderFees.Data public orderFees = OrderFees.Data({ makerFee: 0.04e18, takerFee: 0.08e18 });

    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/
    AccountNFT internal perpsAccountToken;
    ZarosUSD internal usdToken;
    PerpsEngine internal perpsEngine;

    function run() public broadcaster {
        perpsAccountToken = new AccountNFT("Zaros Trading Accounts", "ZRS-TRADE-ACC");
        usdToken = ZarosUSD(vm.envAddress("ZRSUSD"));
        ethUsdStreamId = vm.envBytes32("ETH_USD_STREAM_ID");
        ethUsdPriceFeed = vm.envAddress("ETH_USD_PRICE_FEED");
        perpsEngine = new PerpsEngine(mockChainlinkVerifier, address(perpsAccountToken),
         mockRewardDistributorAddress, address(usdToken), mockZarosAddress);

        configureContracts();
        logContracts();
    }

    function configureContracts() internal {
        perpsAccountToken.transferOwnership(address(perpsEngine));

        perpsEngine.setIsCollateralEnabled(address(usdToken), true);

        perpsEngine.createPerpsMarket(
            ETH_USD_MARKET_ID,
            ETH_USD_MARKET_NAME,
            ETH_USD_MARKET_SYMBOL,
            ethUsdStreamId,
            ethUsdPriceFeed,
            ETH_USD_MMR,
            ETH_USD_MAX_OI,
            ETH_USD_MIN_IMR,
            orderFees
        );
    }

    function logContracts() internal view {
        console.log("Perps Account Token: ");
        console.log(address(perpsAccountToken));

        console.log("Perps Engine: ");
        console.log(address(perpsEngine));
    }
}
