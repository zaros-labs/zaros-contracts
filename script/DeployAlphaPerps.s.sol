// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

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
    address internal chainlinkForwarder;
    address internal chainlinkVerifier;
    address internal mockRewardDistributorAddress = address(3);
    address internal mockZarosAddress = address(4);
    address internal ethUsdPriceFeed;
    /// @dev TODO: We need a zrsUSD price feed
    address internal usdcUsdPriceFeed;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/
    AccountNFT internal perpsAccountToken;
    ZarosUSD internal usdToken;
    PerpsEngine internal perpsEngine;
    PerpsEngine internal perpsEngineImplementation;

    function run() public broadcaster {
        chainlinkForwarder = vm.envAddress("CHAINLINK_FORWARDER");
        chainlinkVerifier = vm.envAddress("CHAINLINK_VERIFIER");
        perpsAccountToken = new AccountNFT("Zaros Trading Accounts", "ZRS-TRADE-ACC");
        usdToken = ZarosUSD(vm.envAddress("ZRSUSD"));
        ethUsdPriceFeed = vm.envAddress("ETH_USD_PRICE_FEED");
        usdcUsdPriceFeed = vm.envAddress("USDC_USD_PRICE_FEED");

        perpsEngineImplementation = new PerpsEngine();
        bytes memory initializeData = abi.encodeWithSelector(
            perpsEngineImplementation.initialize.selector,
            chainlinkForwarder,
            chainlinkVerifier,
            address(perpsAccountToken),
            mockRewardDistributorAddress,
            address(usdToken),
            mockZarosAddress
        );
        (bool success,) = address(perpsEngineImplementation).call(initializeData);
        require(success, "perpsEngineImplementation.initialize failed");

        perpsEngine =
            PerpsEngine(payable(address(new ERC1967Proxy(address(perpsEngineImplementation), initializeData))));

        // TODO: need to update this once we properly configure the CL Data Streams fee payment tokens
        payable(address(perpsEngine)).transfer(1 ether);

        configureContracts();
        logContracts();
    }

    function configureContracts() internal {
        perpsAccountToken.transferOwnership(address(perpsEngine));

        perpsEngine.configureCollateral(address(usdToken), type(uint256).max);

        perpsEngine.configurePriceFeed(address(usdToken), usdcUsdPriceFeed);
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
