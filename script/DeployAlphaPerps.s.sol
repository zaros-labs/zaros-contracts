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

// Open Zeppelin Upgradeable dependencies
import { ERC1967Proxy } from "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

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
    /// @dev TODO: We need a zrsUSD price feed
    address internal usdcUsdPriceFeed;

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
    PerpsEngine internal perpsEngineImplementation;

    function run() public broadcaster {
        perpsAccountToken = new AccountNFT("Zaros Trading Accounts", "ZRS-TRADE-ACC");
        usdToken = ZarosUSD(vm.envAddress("ZRSUSD"));
        ethUsdStreamId = vm.envBytes32("ETH_USD_STREAM_ID");
        ethUsdPriceFeed = vm.envAddress("ETH_USD_PRICE_FEED");
        usdcUsdPriceFeed = vm.envAddress("USDC_USD_PRICE_FEED");

        perpsEngineImplementation = new PerpsEngine();
        bytes memory initializeData = abi.encodeWithSelector(
            perpsEngineImplementation.initialize.selector,
            mockChainlinkVerifier,
            address(perpsAccountToken),
            mockRewardDistributorAddress,
            address(usdToken),
            mockZarosAddress
        );
        (bool success,) = address(perpsEngineImplementation).call(initializeData);
        require(success, "perpsEngineImplementation.initialize failed");

        perpsEngine = PerpsEngine(address(new ERC1967Proxy(address(perpsEngineImplementation), initializeData)));

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
        console.log("Perps Account NFT: ");
        console.log(address(perpsAccountToken));

        console.log("Perps Engine Implementation: ");
        console.log(address(perpsEngineImplementation));

        console.log("Perps Engine Proxy: ");
        console.log(address(perpsEngine));
    }
}
