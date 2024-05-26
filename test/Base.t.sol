// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;

// Zaros dependencies
import { AccountNFT } from "@zaros/account-nft/AccountNFT.sol";
import { RootProxy } from "@zaros/tree-proxy/RootProxy.sol";
import { PerpsEngine } from "@zaros/perpetuals/PerpsEngine.sol";
import { IPerpsEngine as IPerpsEngineBranches } from "@zaros/perpetuals/PerpsEngine.sol";
import { MockERC20 } from "./mocks/MockERC20.sol";
import { MockPriceFeed } from "./mocks/MockPriceFeed.sol";
import { MockUSDToken } from "./mocks/MockUSDToken.sol";
import { Storage } from "./utils/Storage.sol";
import { Users, MockPriceAdapters } from "./utils/Types.sol";
import { ProtocolConfiguration } from "script/utils/ProtocolConfiguration.sol";
import {
    deployBranches,
    getBranchesSelectors,
    getBranchUpgrades,
    getInitializables,
    getInitializePayloads,
    deployHarnesses
} from "script/helpers/TreeProxyHelpers.sol";
import { GlobalConfigurationHarness } from "test/harnesses/perpetuals/leaves/GlobalConfigurationHarness.sol";
import { MarginCollateralConfigurationHarness } from
    "test/harnesses/perpetuals/leaves/MarginCollateralConfigurationHarness.sol";
import { MarketConfigurationHarness } from "test/harnesses/perpetuals/leaves/MarketConfigurationHarness.sol";
import { MarketOrderHarness } from "test/harnesses/perpetuals/leaves/MarketOrderHarness.sol";
import { PerpMarketHarness } from "test/harnesses/perpetuals/leaves/PerpMarketHarness.sol";
import { PositionHarness } from "test/harnesses/perpetuals/leaves/PositionHarness.sol";
import { SettlementConfigurationHarness } from "test/harnesses/perpetuals/leaves/SettlementConfigurationHarness.sol";
import { TradingAccountHarness } from "test/harnesses/perpetuals/leaves/TradingAccountHarness.sol";
import { MockChainlinkFeeManager } from "test/mocks/MockChainlinkFeeManager.sol";
import { MockChainlinkVerifier } from "test/mocks/MockChainlinkVerifier.sol";
import { FeeRecipients } from "@zaros/perpetuals/leaves/FeeRecipients.sol";
import { IFeeManager } from "@zaros/external/chainlink/interfaces/IFeeManager.sol";
import { AutomationHelpers } from "script/helpers/AutomationHelpers.sol";
import { IVerifierProxy } from "@zaros/external/chainlink/interfaces/IVerifierProxy.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";

// Open Zeppelin Upgradeable dependencies
import { ERC1967Proxy } from "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

// PRB Math dependencies
import { uMAX_UD60x18 } from "@prb-math/UD60x18.sol";

// PRB Test dependencies
import { PRBTest } from "prb-test/PRBTest.sol";

// Forge dependencies
import { StdCheats, StdUtils } from "forge-std/Test.sol";

abstract contract IPerpsEngine is
    IPerpsEngineBranches,
    GlobalConfigurationHarness,
    MarginCollateralConfigurationHarness,
    MarketConfigurationHarness,
    MarketOrderHarness,
    PerpMarketHarness,
    PositionHarness,
    SettlementConfigurationHarness,
    TradingAccountHarness
{ }

abstract contract Base_Test is PRBTest, StdCheats, StdUtils, ProtocolConfiguration, Storage {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    Users internal users;
    address internal mockChainlinkFeeManager;
    address internal mockChainlinkVerifier;
    FeeRecipients.Data internal feeRecipients;
    address internal liquidationKeeper;

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    AccountNFT internal tradingAccountToken;
    MockERC20 internal mockWstEth;
    MockUSDToken internal usdToken;
    IPerpsEngine internal perpsEngine;
    IPerpsEngine internal perpsEngineImplementation;

    MockPriceAdapters internal mockPriceAdapters;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        users = Users({
            owner: createUser({ name: "Owner" }),
            marginCollateralRecipient: createUser({ name: "Margin Collateral Recipient" }),
            orderFeeRecipient: createUser({ name: "Order Fee Recipient" }),
            settlementFeeRecipient: createUser({ name: "Settlement Fee Recipient" }),
            keepersForwarder: createUser({ name: "Keepers Forwarder" }),
            naruto: createUser({ name: "Naruto Uzumaki" }),
            sasuke: createUser({ name: "Sasuke Uchiha" }),
            sakura: createUser({ name: "Sakura Haruno" }),
            madara: createUser({ name: "Madara Uchiha" })
        });
        vm.startPrank({ msgSender: users.owner });

        tradingAccountToken = new AccountNFT("Zaros Trading Accounts", "ZRS-TRADE-ACC", users.owner);
        usdToken = new MockUSDToken({ owner: users.owner, deployerBalance: 100_000_000e18 });
        mockWstEth = new MockERC20({
            name: "Wrapped Staked Ether",
            symbol: "wstETH",
            decimals_: 18,
            deployerBalance: 100_000_000e18
        });

        MockPriceFeed mockBtcUsdPriceAdapter = new MockPriceFeed(18, int256(MOCK_BTC_USD_PRICE));
        MockPriceFeed mockEthUsdPriceAdapter = new MockPriceFeed(18, int256(MOCK_ETH_USD_PRICE));
        MockPriceFeed mockLinkUsdPriceAdapter = new MockPriceFeed(18, int256(MOCK_LINK_USD_PRICE));
        MockPriceFeed mockUsdcUsdPriceAdapter = new MockPriceFeed(6, int256(MOCK_USDC_USD_PRICE));
        MockPriceFeed mockWstEthUsdPriceAdapter = new MockPriceFeed(18, int256(MOCK_WSTETH_USD_PRICE));

        mockPriceAdapters = MockPriceAdapters({
            mockBtcUsdPriceAdapter: mockBtcUsdPriceAdapter,
            mockEthUsdPriceAdapter: mockEthUsdPriceAdapter,
            mockLinkUsdPriceAdapter: mockLinkUsdPriceAdapter,
            mockUsdcUsdPriceAdapter: mockUsdcUsdPriceAdapter,
            mockWstEthUsdPriceAdapter: mockWstEthUsdPriceAdapter
        });

        bool isTestnet = false;
        address[] memory branches = deployBranches(isTestnet);
        bytes4[][] memory branchesSelectors = getBranchesSelectors(isTestnet);
        RootProxy.BranchUpgrade[] memory branchUpgrades =
            getBranchUpgrades(branches, branchesSelectors, RootProxy.BranchUpgradeAction.Add);
        address[] memory initializables = getInitializables(branches);
        bytes[] memory initializePayloads =
            getInitializePayloads(users.owner, address(tradingAccountToken), address(usdToken));

        branchUpgrades = deployHarnesses(branchUpgrades);

        RootProxy.InitParams memory initParams = RootProxy.InitParams({
            initBranches: branchUpgrades,
            initializables: initializables,
            initializePayloads: initializePayloads
        });
        perpsEngine = IPerpsEngine(address(new PerpsEngine(initParams)));

        configureContracts();

        vm.label({ account: address(tradingAccountToken), newLabel: "Trading Account NFT" });
        vm.label({ account: address(usdToken), newLabel: "Zaros USD" });
        vm.label({ account: address(perpsEngine), newLabel: "Perps Engine" });

        approveContracts();
        changePrank({ msgSender: users.naruto });

        mockChainlinkFeeManager = address(new MockChainlinkFeeManager());
        mockChainlinkVerifier = address(new MockChainlinkVerifier(IFeeManager(mockChainlinkFeeManager)));
        feeRecipients = FeeRecipients.Data({
            marginCollateralRecipient: users.marginCollateralRecipient,
            orderFeeRecipient: users.orderFeeRecipient,
            settlementFeeRecipient: users.settlementFeeRecipient
        });

        setupMarketsConfig();
        configureLiquidationKeepers();

        vm.label({ account: mockChainlinkFeeManager, newLabel: "Chainlink Fee Manager" });
        vm.label({ account: mockChainlinkVerifier, newLabel: "Chainlink Verifier" });
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Generates a user, labels its address, and funds it with test assets.
    function createUser(string memory name) internal returns (address payable) {
        address payable user = payable(makeAddr(name));
        vm.deal({ account: user, newBalance: 100 ether });

        return user;
    }

    /// @dev Approves all Zaros contracts to spend the test assets.
    function approveContracts() internal {
        changePrank({ msgSender: users.naruto });
        usdToken.approve({ spender: address(perpsEngine), value: type(uint256).max });
        mockWstEth.approve({ spender: address(perpsEngine), value: uMAX_UD60x18 });

        changePrank({ msgSender: users.sasuke });
        usdToken.approve({ spender: address(perpsEngine), value: uMAX_UD60x18 });
        mockWstEth.approve({ spender: address(perpsEngine), value: uMAX_UD60x18 });

        changePrank({ msgSender: users.sakura });
        usdToken.approve({ spender: address(perpsEngine), value: uMAX_UD60x18 });
        mockWstEth.approve({ spender: address(perpsEngine), value: uMAX_UD60x18 });

        changePrank({ msgSender: users.madara });
        usdToken.approve({ spender: address(perpsEngine), value: uMAX_UD60x18 });
        mockWstEth.approve({ spender: address(perpsEngine), value: uMAX_UD60x18 });

        // Finally, change the active prank back to the Admin.
        changePrank({ msgSender: users.owner });
    }

    function configureContracts() internal {
        tradingAccountToken.transferOwnership(address(perpsEngine));

        // TODO: Temporary, switch to liquidity engine
        usdToken.addToFeatureFlagAllowlist(MINT_FEATURE_FLAG, address(perpsEngine));

        perpsEngine.configureMarginCollateral(
            address(usdToken),
            USDZ_DEPOSIT_CAP,
            USDZ_LOAN_TO_VALUE,
            address(mockPriceAdapters.mockUsdcUsdPriceAdapter)
        );
        perpsEngine.configureMarginCollateral(
            address(mockWstEth),
            WSTETH_DEPOSIT_CAP,
            WSTETH_LOAN_TO_VALUE,
            address(mockPriceAdapters.mockWstEthUsdPriceAdapter)
        );

        address[] memory collateralLiquidationPriority = new address[](2);
        collateralLiquidationPriority[0] = address(usdToken);
        collateralLiquidationPriority[1] = address(mockWstEth);

        perpsEngine.configureCollateralLiquidationPriority(collateralLiquidationPriority);
    }

    function configureLiquidationKeepers() internal {
        changePrank({ msgSender: users.owner });
        liquidationKeeper =
            AutomationHelpers.deployLiquidationKeeper(users.owner, address(perpsEngine), users.settlementFeeRecipient);

        address[] memory liquidators = new address[](1);
        bool[] memory liquidatorStatus = new bool[](1);

        liquidators[0] = liquidationKeeper;
        liquidatorStatus[0] = true;

        perpsEngine.configureLiquidators(liquidators, liquidatorStatus);

        changePrank({ msgSender: users.naruto });
    }

    function configureSystemParameters() internal {
        perpsEngine.configureSystemParameters({
            maxPositionsPerAccount: MAX_POSITIONS_PER_ACCOUNT,
            marketOrderMaxLifetime: MARKET_ORDER_MAX_LIFETIME,
            liquidationFeeUsdX18: LIQUIDATION_FEE_USD,
            marginCollateralRecipient: feeRecipients.marginCollateralRecipient,
            orderFeeRecipient: feeRecipients.orderFeeRecipient,
            settlementFeeRecipient: feeRecipients.settlementFeeRecipient
        });
    }

    function createPerpMarkets() internal {
        createPerpMarkets(
            users.owner, perpsEngine, INITIAL_MARKET_ID, FINAL_MARKET_ID, IVerifierProxy(mockChainlinkVerifier), true
        );
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    CALL EXPECTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Expects a call to {IERC20.transfer}.
    function expectCallToTransfer(IERC20 asset, address to, uint256 amount) internal {
        vm.expectCall({ callee: address(asset), data: abi.encodeCall(IERC20.transfer, (to, amount)) });
    }

    /// @dev Expects a call to {IERC20.transferFrom}.
    function expectCallToTransferFrom(IERC20 asset, address from, address to, uint256 amount) internal {
        vm.expectCall({ callee: address(asset), data: abi.encodeCall(IERC20.transferFrom, (from, to, amount)) });
    }
}
