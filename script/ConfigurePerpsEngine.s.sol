// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { AccountNFT } from "@zaros/account-nft/AccountNFT.sol";
import { LiquidationUpkeep } from "@zaros/external/chainlink/upkeeps/liquidation/LiquidationUpkeep.sol";
import { IPerpsEngine } from "@zaros/markets/perps/interfaces/IPerpsEngine.sol";
import { LimitedMintingERC20 } from "@zaros/testnet/LimitedMintingERC20.sol";
import { BaseScript } from "./Base.s.sol";
import { Markets } from "./markets/Markets.sol";

// Forge dependencies
import { console } from "forge-std/console.sol";

contract ConfigurePerpsEngine is BaseScript, Markets {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/
    /// @dev TODO: We need a USDz price feed
    address internal usdcUsdPriceFeed;
    uint256 internal upkeepInitialLinkFunding;

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
        usdcUsdPriceFeed = vm.envAddress("USDC_USD_PRICE_FEED");
        upkeepInitialLinkFunding = vm.envUint("UPKEEP_INITIAL_LINK_FUNDING");

        // TODO: need to update this once we properly configure the CL Data Streams fee payment tokens
        payable(address(perpsEngine)).transfer(0.1 ether);

        configureContracts();
    }

    function configureContracts() internal {
        perpsAccountToken.transferOwnership(address(perpsEngine));

        // TODO: add missing configurations

        perpsEngine.setPerpsAccountToken(address(perpsAccountToken));

        perpsEngine.configureSystemParameters(
            MAX_POSITIONS_PER_ACCOUNT, MARKET_ORDER_MAX_LIFETIME, MIN_TRADE_SIZE_USD, LIQUIDATION_FEE_USD
        );

        address[] memory collateralLiquidationPriority = new address[](2);
        collateralLiquidationPriority[0] = usdToken;
        collateralLiquidationPriority[1] = usdc;

        perpsEngine.configureCollateralPriority(collateralLiquidationPriority);

        // TODO: add margin collateral configuration paremeters to a JSON file and use ffi
        perpsEngine.configureMarginCollateral(usdToken, USDZ_DEPOSIT_CAP, USDZ_LOAN_TO_VALUE, usdcUsdPriceFeed);
        perpsEngine.configureMarginCollateral(usdc, USDC_DEPOSIT_CAP, USDC_LOAN_TO_VALUE, usdcUsdPriceFeed);

        address liquidationUpkeep = address(new LiquidationUpkeep());

        console.log("Liquidation Upkeep: ", liquidationUpkeep);
        // AutomationHelpers.registerLiquidationUpkeep({
        //     name: PERPS_LIQUIDATION_UPKEEP_NAME,
        //     liquidationUpkeep: liquidationUpkeep,
        //     link: link,
        //     registrar: automationRegistrar,
        //     adminAddress: EDAO_ADDRESS,
        //     linkAmount: upkeepInitialLinkFunding
        // });

        address[] memory liquidators = new address[](1);
        bool[] memory liquidatorStatus = new bool[](1);

        liquidators[0] = liquidationUpkeep;
        liquidatorStatus[0] = true;

        perpsEngine.configureLiquidators(liquidators, liquidatorStatus);

        LimitedMintingERC20(usdToken).transferOwnership(address(perpsEngine));
    }
}
