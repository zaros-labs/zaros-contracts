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
    address internal mockChainlinkForwarder = address(1);
    address internal mockChainlinkVerifier = address(2);
    address internal mockPerpsAccountTokenAddress = address(3);
    address internal mockRewardDistributorAddress = address(4);
    address internal mockZarosAddress = address(5);

    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/
    ZarosUSD internal usdToken;
    PerpsEngine internal perpsEngine;
    PerpsEngine internal perpsEngineImplementation;

    function run() public broadcaster {
        usdToken = ZarosUSD(vm.envAddress("USDZ"));

        perpsEngineImplementation = new PerpsEngine();
        bytes memory initializeData = abi.encodeWithSelector(
            perpsEngineImplementation.initialize.selector,
            mockChainlinkForwarder,
            mockChainlinkVerifier,
            mockPerpsAccountTokenAddress,
            mockRewardDistributorAddress,
            address(usdToken),
            mockZarosAddress
        );
        (bool success,) = address(perpsEngineImplementation).call(initializeData);
        require(success, "perpsEngineImplementation.initialize failed");

        perpsEngine = PerpsEngine(payable(vm.envAddress("PERPS_ENGINE")));
        perpsEngine.upgradeTo(address(perpsEngineImplementation));

        logContracts();
    }

    function logContracts() internal view {
        console.log("New Perps Engine Implementation: ");
        console.log(address(perpsEngineImplementation));

        console.log("Perps Engine Proxy: ");
        console.log(address(perpsEngine));
    }
}
