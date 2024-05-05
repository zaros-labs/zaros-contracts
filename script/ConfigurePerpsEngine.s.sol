// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;

// Zaros dependencies
import { AccountNFT } from "@zaros/account-nft/AccountNFT.sol";
import { LiquidationKeeper } from "@zaros/external/chainlink/keepers/liquidation/LiquidationKeeper.sol";
import { IPerpsEngine } from "@zaros/perpetuals/interfaces/IPerpsEngine.sol";
import { LimitedMintingERC20 } from "@zaros/testnet/LimitedMintingERC20.sol";
import { BaseScript } from "./Base.s.sol";
import { ProtocolConfiguration } from "./utils/ProtocolConfiguration.sol";

// Forge dependencies
import { console } from "forge-std/console.sol";

contract ConfigurePerpsEngine is BaseScript, ProtocolConfiguration {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/
    address internal usdzUsdPriceFeed;
    address internal usdcUsdPriceFeed;
    uint256 internal keeperInitialLinkFunding;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/
    AccountNFT internal perpsAccountToken;
    address internal usdToken;
    address internal usdc;
    address internal link;
    address internal automationRegistrar;
    IPerpsEngine internal perpsEngine;

    function run() public broadcaster {
        perpsAccountToken = AccountNFT(vm.envAddress("PERPS_ACCOUNT_NFT"));
        perpsEngine = IPerpsEngine(vm.envAddress("PERPS_ENGINE"));
        usdToken = vm.envAddress("USDZ");
        usdc = vm.envAddress("USDC");
        link = vm.envAddress("LINK");
        automationRegistrar = vm.envAddress("CHAINLINK_AUTOMATION_REGISTRAR");
        usdzUsdPriceFeed = vm.envAddress("USDZ_USD_PRICE_FEED");
        usdcUsdPriceFeed = vm.envAddress("USDC_USD_PRICE_FEED");
        keeperInitialLinkFunding = vm.envUint("KEEPER_INITIAL_LINK_FUNDING");

        payable(address(perpsEngine)).transfer(0.03 ether);

        configureContracts();
    }

    function configureContracts() internal {
        perpsAccountToken.transferOwnership(address(perpsEngine));

        perpsEngine.setPerpsAccountToken(address(perpsAccountToken));

        perpsEngine.configureSystemParameters({
            maxPositionsPerAccount: MAX_POSITIONS_PER_ACCOUNT,
            marketOrderMaxLifetime: MARKET_ORDER_MAX_LIFETIME,
            liquidationFeeUsdX18: LIQUIDATION_FEE_USD
        });

        address[] memory collateralLiquidationPriority = new address[](2);
        collateralLiquidationPriority[0] = usdToken;
        collateralLiquidationPriority[1] = usdc;

        perpsEngine.configureCollateralLiquidationPriority(collateralLiquidationPriority);

        perpsEngine.configureMarginCollateral(usdToken, USDZ_DEPOSIT_CAP, USDZ_LOAN_TO_VALUE, usdzUsdPriceFeed);
        perpsEngine.configureMarginCollateral(usdc, USDC_DEPOSIT_CAP, USDC_LOAN_TO_VALUE, usdcUsdPriceFeed);

        address liquidationKeeper = address(new LiquidationKeeper());

        console.log("Liquidation Keeper: ", liquidationKeeper);
        // AutomationHelpers.registerLiquidationKeeper({
        //     name: PERPS_LIQUIDATION_KEEPER_NAME,
        //     liquidationKeeper: liquidationKeeper,
        //     link: link,
        //     registrar: automationRegistrar,
        //     adminAddress: MSIG_ADDRESS,
        //     linkAmount: keeperInitialLinkFunding
        // });

        address[] memory liquidators = new address[](1);
        bool[] memory liquidatorStatus = new bool[](1);

        liquidators[0] = liquidationKeeper;
        liquidatorStatus[0] = true;

        perpsEngine.configureLiquidators(liquidators, liquidatorStatus);

        LimitedMintingERC20(usdToken).transferOwnership(address(perpsEngine));
    }
}
