// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { AccountNFT } from "@zaros/account-nft/AccountNFT.sol";
import { Diamond } from "@zaros/diamonds/Diamond.sol";
import { IDiamond } from "@zaros/diamonds/interfaces/IDiamond.sol";
import { IPerpsEngine } from "@zaros/markets/perps/interfaces/IPerpsEngine.sol";
import { GlobalConfigurationModule } from "@zaros/markets/perps/modules/GlobalConfigurationModule.sol";
import { OrderModule } from "@zaros/markets/perps/modules/OrderModule.sol";
import { PerpMarketModule } from "@zaros/markets/perps/modules/PerpMarketModule.sol";
import { PerpsAccountModule } from "@zaros/markets/perps/modules/PerpsAccountModule.sol";
import { SettlementModule } from "@zaros/markets/perps/modules/SettlementModule.sol";
import { OrderFees } from "@zaros/markets/perps/storage/OrderFees.sol";
import { USDToken } from "@zaros/usd/USDToken.sol";
import { BaseScript } from "./Base.s.sol";

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
    /// @dev TODO: We need a USDz price feed
    address internal usdcUsdPriceFeed;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/
    AccountNFT internal perpsAccountToken;
    USDToken internal usdToken;
    IPerpsEngine internal perpsEngine;

    function run() public broadcaster {
        // chainlinkForwarder = vm.envAddress("CHAINLINK_FORWARDER");
        // chainlinkVerifier = vm.envAddress("CHAINLINK_VERIFIER");
        perpsAccountToken = new AccountNFT("Zaros Trading Accounts", "ZRS-TRADE-ACC", deployer);
        usdToken = USDToken(vm.envAddress("USDZ"));
        usdcUsdPriceFeed = vm.envAddress("USDC_USD_PRICE_FEED");

        (
            address globalConfigurationModule,
            address orderModule,
            address perpMarketModule,
            address perpsAccountModule,
            address settlementModule
        ) = deployModules();

        // perpsEngineImplementation = new PerpsEngine();
        bytes memory initializeData = abi.encodeWithSelector(
            perpsEngineImplementation.initialize.selector,
            deployer,
            address(perpsAccountToken),
            mockRewardDistributorAddress,
            address(usdToken),
            mockZarosAddress
        );

        // (bool success,) = address(perpsEngineImplementation).call(initializeData);
        // require(success, "perpsEngineImplementation.initialize failed");

        // TODO: need to update this once we properly configure the CL Data Streams fee payment tokens
        payable(address(perpsEngine)).transfer(1 ether);

        configureContracts();
        logContracts();
    }

    function deployModules() internal returns (address, address, address, address, address) {
        address globalConfigurationModule = address(new GlobalConfigurationModule());
        address orderModule = address(new OrderModule());
        address perpMarketModule = address(new PerpMarketModule());
        address perpsAccountModule = address(new PerpsAccountModule());
        address settlementModule = address(new SettlementModule());

        return (globalConfigurationModule, orderModule, perpMarketModule, perpsAccountModule, settlementModule);
    }

    function configureContracts() internal {
        perpsAccountToken.transferOwnership(address(perpsEngine));

        perpsEngine.configureMarginCollateral(address(usdToken), type(uint128).max, 100e18, usdcUsdPriceFeed);
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
