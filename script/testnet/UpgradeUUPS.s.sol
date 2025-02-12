// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

// Zaros dependencies
import { MarketOrderKeeper } from "@zaros/external/chainlink/keepers/market-order/MarketOrderKeeper.sol";
import { LimitedMintingERC20 } from "testnet/LimitedMintingERC20.sol";
import { BaseScript } from "../Base.s.sol";
import { LimitedMintingWETH } from "testnet/LimitedMintingWETH.sol";

// Open Zeppelin dependencies
import { ERC1967Proxy } from "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import { UUPSUpgradeable } from "@openzeppelin/proxy/utils/UUPSUpgradeable.sol";

// Forge dependencies
import { console } from "forge-std/console.sol";

contract UpgradeUUPS is BaseScript {
    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/
    LimitedMintingERC20 internal usdc;
    LimitedMintingWETH internal wEth;
    LimitedMintingERC20 internal usdToken;

    address internal forwarder;
    MarketOrderKeeper internal btcUsdMarketOrderKeeper;

    function run() public broadcaster {
        usdc = LimitedMintingERC20(vm.envAddress("USDC"));
        wEth = LimitedMintingWETH(vm.envAddress("WETH"));

        address usdcNewImplementation = address(new LimitedMintingERC20());

        address wEthNewImplementation = address(new LimitedMintingWETH());

        UUPSUpgradeable(address(usdc)).upgradeToAndCall(usdcNewImplementation, bytes(""));

        UUPSUpgradeable(address(wEth)).upgradeToAndCall(wEthNewImplementation, bytes(""));

        // btcUsdMarketOrderKeeper.setForwarder(forwarder);
    }
}
