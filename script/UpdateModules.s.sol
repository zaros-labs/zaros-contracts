// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { AccountNFT } from "@zaros/account-nft/AccountNFT.sol";
import { IDiamond } from "@zaros/diamonds/interfaces/IDiamond.sol";
import { Diamond } from "@zaros/diamonds/Diamond.sol";
import { DiamondCutModule } from "@zaros/diamonds/modules/DiamondCutModule.sol";
import { DiamondLoupeModule } from "@zaros/diamonds/modules/DiamondLoupeModule.sol";
import { IPerpsEngine } from "@zaros/markets/perps/interfaces/IPerpsEngine.sol";
import { GlobalConfigurationModule } from "@zaros/markets/perps/modules/GlobalConfigurationModule.sol";
import { OrderModule } from "@zaros/markets/perps/modules/OrderModule.sol";
import { PerpMarketModule } from "@zaros/markets/perps/modules/PerpMarketModule.sol";
import { PerpsAccountModule } from "@zaros/markets/perps/modules/PerpsAccountModule.sol";
import { SettlementModule } from "@zaros/markets/perps/modules/SettlementModule.sol";
import { OrderFees } from "@zaros/markets/perps/storage/OrderFees.sol";
import { USDToken } from "@zaros/usd/USDToken.sol";
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
    address internal mockLiquidityEngineAddress = address(5);

    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/
    USDToken internal usdToken;
    IPerpsEngine internal perpsEngine;

    function run() public broadcaster {
        usdToken = USDToken(vm.envAddress("USDZ"));

        address[] memory modules = deployModules();
        bytes4[][] memory modulesSelectors = getModulesSelectors();

        IDiamond.FacetCut[] memory facetCuts = getFacetCuts(modules, modulesSelectors);
        address[] memory initializables;
        bytes[] memory initializePayloads;

        perpsEngine = IPerpsEngine(payable(vm.envAddress("PERPS_ENGINE")));
        perpsEngine.updateModules(facetCuts, initializables, initializePayloads);

        logContracts(modules);
    }

}
