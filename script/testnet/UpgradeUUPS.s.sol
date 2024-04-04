// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { MarketOrderKeeper } from "@zaros/external/chainlink/keepers/market-order/MarketOrderKeeper.sol";
import { LimitedMintingERC20 } from "@zaros/testnet/LimitedMintingERC20.sol";
import { BaseScript } from "../Base.s.sol";

// Open Zeppelin dependencies
import { ERC1967Proxy } from "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import { UUPSUpgradeable } from "@openzeppelin/proxy/utils/UUPSUpgradeable.sol";

// Forge dependencies
import { console } from "forge-std/console.sol";

contract UpdateUUPS is BaseScript {
    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/
    LimitedMintingERC20 internal usdc;
    LimitedMintingERC20 internal usdz;

    address internal forwarder;
    MarketOrderKeeper internal ethUsdMarketOrderKeeper;

    function run() public broadcaster {
        // usdc = LimitedMintingERC20(vm.envAddress("USDC"));

        ethUsdMarketOrderKeeper = MarketOrderKeeper(vm.envAddress("ETH_USD_MARKET_ORDER_KEEPER"));
        // forwarder = vm.envAddress("KEEPER_FORWARDER");
        // address newImplementation = address(new LimitedMintingERC20());
        address ethUsdMarketOrderKeeperNewImplementation = address(new MarketOrderKeeper());

        UUPSUpgradeable(address(ethUsdMarketOrderKeeper)).upgradeToAndCall(
            ethUsdMarketOrderKeeperNewImplementation, bytes("")
        );

        // ethUsdMarketOrderKeeper.setForwarder(forwarder);
    }
}
