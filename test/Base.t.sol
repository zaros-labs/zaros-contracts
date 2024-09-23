// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;

// Zaros dependencies source
import { TradingAccountNFT } from "@zaros/trading-account-nft/TradingAccountNFT.sol";
import { RootProxy } from "@zaros/tree-proxy/RootProxy.sol";
import { PerpsEngine } from "@zaros/perpetuals/PerpsEngine.sol";
import { IPerpsEngine as IPerpsEngineBranches } from "@zaros/perpetuals/PerpsEngine.sol";
import { IVerifierProxy } from "@zaros/external/chainlink/interfaces/IVerifierProxy.sol";
import { Constants } from "@zaros/utils/Constants.sol";
import { PremiumReport } from "@zaros/external/chainlink/interfaces/IStreamsLookupCompatible.sol";
import { PerpsEngineConfigurationBranch } from "@zaros/perpetuals/branches/PerpsEngineConfigurationBranch.sol";
import { Math } from "@zaros/utils/Math.sol";
import { SettlementConfiguration } from "@zaros/perpetuals/leaves/SettlementConfiguration.sol";
import { OrderBranch } from "@zaros/perpetuals/branches/OrderBranch.sol";
import { FeeRecipients } from "@zaros/perpetuals/leaves/FeeRecipients.sol";
import { IFeeManager } from "@zaros/external/chainlink/interfaces/IFeeManager.sol";
import { PriceAdapter } from "@zaros/utils/PriceAdapter.sol";
import { MarketMakingEngine } from "@zaros/market-making/MarketMakingEngine.sol";
import { MarketMakingEngineConfigurationBranch } from "@zaros/market-making/branches/MarketMakingEngineConfigurationBranch.sol";
import { MarketMakingEngine } from "@zaros/market-making/MarketMakingEngine.sol";
import { IMarketMakingEngine as IMarketMakingEngineBranches } from "@zaros/market-making/MarketMakingEngine.sol";
import { Collateral } from "@zaros/market-making/leaves/Collateral.sol";
import { PriceAdapter } from "@zaros/utils/PriceAdapter.sol";

// Zaros dependencies test
import { MockPriceFeed } from "test/mocks/MockPriceFeed.sol";
import { MockSequencerUptimeFeed } from "test/mocks/MockSequencerUptimeFeed.sol";
import { MockUsdToken } from "test/mocks/MockUsdToken.sol";
import { Storage } from "test/utils/Storage.sol";
import { Users, User } from "test/utils/Types.sol";
import { MockERC20 } from "test/mocks/MockERC20.sol";
import { ZlpVault } from "@zaros/zlp/ZlpVault.sol";
import { PerpsEngineConfigurationHarness } from "test/harnesses/perpetuals/leaves/PerpsEngineConfigurationHarness.sol";
import { MarginCollateralConfigurationHarness } from
    "test/harnesses/perpetuals/leaves/MarginCollateralConfigurationHarness.sol";
import { MarketConfigurationHarness } from "test/harnesses/perpetuals/leaves/MarketConfigurationHarness.sol";
import { MarketOrderHarness } from "test/harnesses/perpetuals/leaves/MarketOrderHarness.sol";
import { PerpMarketHarness } from "test/harnesses/perpetuals/leaves/PerpMarketHarness.sol";
import { PositionHarness } from "test/harnesses/perpetuals/leaves/PositionHarness.sol";
import { SettlementConfigurationHarness } from "test/harnesses/perpetuals/leaves/SettlementConfigurationHarness.sol";
import { TradingAccountHarness } from "test/harnesses/perpetuals/leaves/TradingAccountHarness.sol";
import { ReferralHarness } from "test/harnesses/perpetuals/leaves/ReferralHarness.sol";
import { CustomReferralConfigurationHarness } from
    "test/harnesses/perpetuals/leaves/CustomReferralConfigurationHarness.sol";
import { MockChainlinkFeeManager } from "test/mocks/MockChainlinkFeeManager.sol";
import { MockChainlinkVerifier } from "test/mocks/MockChainlinkVerifier.sol";
import { VaultHarness } from "test/harnesses/market-making/leaves/VaultHarness.sol";
import { WithdrawalRequestHarness } from "test/harnesses/market-making/leaves/WithdrawalRequestHarness.sol";
import { DistributionHarness } from "test/harnesses/market-making/leaves/DistributionHarness.sol";
import { CollateralHarness } from "test/harnesses/market-making/leaves/CollateralHarness.sol";
import { MarketDebtHarness } from "test/harnesses/market-making/leaves/MarketDebtHarness.sol";
import { MarketMakingEngineConfigurationHarness } from
    "test/harnesses/market-making/leaves/MarketMakingEngineConfigurationHarness.sol";
import { SwapStrategyHarness } from "test/harnesses/market-making/leaves/SwapStrategyHarness.sol";
import { CollateralHarness } from "test/harnesses/market-making/leaves/CollateralHarness.sol";
import { FeeRecipientHarness } from "test/harnesses/market-making/leaves/FeeRecipientHarness.sol";

// Zaros dependencies script
import { ProtocolConfiguration } from "script/utils/ProtocolConfiguration.sol";
import {
    deployPerpsEngineBranches,
    getPerpsEngineBranchesSelectors,
    getBranchUpgrades,
    getPerpsEngineInitializables,
    getPerpsEngineInitializePayloads,
    deployPerpsEngineHarnesses,
    deployMarketMakingEngineBranches,
    getMarketMakerBranchesSelectors,
    deployMarketMakingHarnesses
} from "script/utils/TreeProxyUtils.sol";
import { ChainlinkAutomationUtils } from "script/utils/ChainlinkAutomationUtils.sol";

// Open Zeppelin dependencies
import { ERC1967Proxy } from "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import { ERC20, IERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { SD59x18, sd59x18, unary } from "@prb-math/SD59x18.sol";
import { UD60x18, ud60x18, uMAX_UD60x18 } from "@prb-math/UD60x18.sol";

// PRB Test dependencies
import { PRBTest } from "@prb-test/PRBTest.sol";

// Forge dependencies
import { StdCheats, StdUtils } from "forge-std/Test.sol";

abstract contract IPerpsEngine is
    IPerpsEngineBranches,
    PerpsEngineConfigurationHarness,
    MarginCollateralConfigurationHarness,
    MarketConfigurationHarness,
    MarketOrderHarness,
    PerpMarketHarness,
    PositionHarness,
    SettlementConfigurationHarness,
    TradingAccountHarness,
    ReferralHarness,
    CustomReferralConfigurationHarness
{ }

abstract contract IMarketMakingEngine is
    IMarketMakingEngineBranches,
    VaultHarness,
    WithdrawalRequestHarness,
    CollateralHarness,
    DistributionHarness,
    MarketDebtHarness,
    MarketMakingEngineConfigurationHarness,
    SwapStrategyHarness,
    FeeRecipientHarness
{ }


abstract contract Base_Test is PRBTest, StdCheats, StdUtils, ProtocolConfiguration, Storage {
    using Math for UD60x18;
    using SafeCast for int256;
    using SafeCast for uint256;

    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    Users internal users;
    address internal mockChainlinkFeeManager;
    address internal mockChainlinkVerifier;
    address internal mockSequencerUptimeFeed;
    FeeRecipients.Data internal feeRecipients;
    address internal liquidationKeeper;
    uint32 internal constant MOCK_PRICE_FEED_HEARTBEAT_SECONDS = 86_400;

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    TradingAccountNFT internal tradingAccountToken;

    MockERC20 internal usdc;
    MockUsdToken internal usdToken;
    MockERC20 internal wstEth;
    MockERC20 internal weEth;
    MockERC20 internal wEth;
    MockERC20 internal wBtc;

    IPerpsEngine internal perpsEngine;
    IPerpsEngine internal perpsEngineImplementation;

    IMarketMakingEngine internal marketMakingEngine;
    IMarketMakingEngine internal marketMakingEngineImplementation;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        users = Users({
            owner: createUser({ name: "Owner" }),
            marginCollateralRecipient: createUser({ name: "Margin Collateral Recipient" }),
            orderFeeRecipient: createUser({ name: "Order Fee Recipient" }),
            settlementFeeRecipient: createUser({ name: "Settlement Fee Recipient" }),
            liquidationFeeRecipient: createUser({ name: "Liquidation Fee Recipient" }),
            keepersForwarder: createUser({ name: "Keepers Forwarder" }),
            naruto: createUser({ name: "Naruto Uzumaki" }),
            sasuke: createUser({ name: "Sasuke Uchiha" }),
            sakura: createUser({ name: "Sakura Haruno" }),
            madara: createUser({ name: "Madara Uchiha" })
        });
        vm.startPrank({ msgSender: users.owner.account });

        address tradingAccountTokenImplementation = address(new TradingAccountNFT());
        bytes memory tradingAccountTokenInitializeData = abi.encodeWithSelector(
            TradingAccountNFT.initialize.selector, users.owner.account, "Zaros Trading Accounts", "ZRS-TRADE-ACC"
        );
        tradingAccountToken = TradingAccountNFT(
            address(new ERC1967Proxy(tradingAccountTokenImplementation, tradingAccountTokenInitializeData))
        );

        // Perps Engine Set Up

        bool isTestnet = false;
        address[] memory branches = deployPerpsEngineBranches(isTestnet);
        bytes4[][] memory branchesSelectors = getPerpsEngineBranchesSelectors(isTestnet);
        RootProxy.BranchUpgrade[] memory branchUpgrades =
            getBranchUpgrades(branches, branchesSelectors, RootProxy.BranchUpgradeAction.Add);
        address[] memory initializables = getPerpsEngineInitializables(branches);
        bytes[] memory initializePayloads = getPerpsEngineInitializePayloads(users.owner.account);

        branchUpgrades = deployPerpsEngineHarnesses(branchUpgrades);

        RootProxy.InitParams memory initParams = RootProxy.InitParams({
            initBranches: branchUpgrades,
            initializables: initializables,
            initializePayloads: initializePayloads
        });

        perpsEngine = IPerpsEngine(address(new PerpsEngine(initParams)));

        uint256[2] memory marginCollateralIdsRange;
        marginCollateralIdsRange[0] = INITIAL_MARGIN_COLLATERAL_ID;
        marginCollateralIdsRange[1] = FINAL_MARGIN_COLLATERAL_ID;

        mockSequencerUptimeFeed = address(new MockSequencerUptimeFeed(0));

        configureMarginCollaterals(
            perpsEngine, marginCollateralIdsRange, true, mockSequencerUptimeFeed, users.owner.account
        );

        usdc = MockERC20(marginCollaterals[USDC_MARGIN_COLLATERAL_ID].marginCollateralAddress);
        usdToken = MockUsdToken(marginCollaterals[USD_TOKEN_MARGIN_COLLATERAL_ID].marginCollateralAddress);
        weEth = MockERC20(marginCollaterals[WEETH_MARGIN_COLLATERAL_ID].marginCollateralAddress);
        wstEth = MockERC20(marginCollaterals[WSTETH_MARGIN_COLLATERAL_ID].marginCollateralAddress);
        wEth = MockERC20(marginCollaterals[WETH_MARGIN_COLLATERAL_ID].marginCollateralAddress);
        wBtc = MockERC20(marginCollaterals[WBTC_MARGIN_COLLATERAL_ID].marginCollateralAddress);

        vm.label({ account: address(usdc), newLabel: marginCollaterals[USDC_MARGIN_COLLATERAL_ID].symbol });
        vm.label({ account: address(usdToken), newLabel: marginCollaterals[USD_TOKEN_MARGIN_COLLATERAL_ID].symbol });
        vm.label({ account: address(weEth), newLabel: marginCollaterals[WEETH_MARGIN_COLLATERAL_ID].symbol });
        vm.label({ account: address(wstEth), newLabel: marginCollaterals[WSTETH_MARGIN_COLLATERAL_ID].symbol });
        vm.label({ account: address(wEth), newLabel: marginCollaterals[WETH_MARGIN_COLLATERAL_ID].symbol });
        vm.label({ account: address(wBtc), newLabel: marginCollaterals[WBTC_MARGIN_COLLATERAL_ID].symbol });

        configureContracts();

        vm.label({ account: address(tradingAccountToken), newLabel: "Trading Account NFT" });
        vm.label({ account: address(perpsEngine), newLabel: "Perps Engine" });

        mockChainlinkFeeManager = address(new MockChainlinkFeeManager());
        mockChainlinkVerifier = address(new MockChainlinkVerifier(IFeeManager(mockChainlinkFeeManager)));
        feeRecipients = FeeRecipients.Data({
            marginCollateralRecipient: users.marginCollateralRecipient.account,
            orderFeeRecipient: users.orderFeeRecipient.account,
            settlementFeeRecipient: users.settlementFeeRecipient.account
        });

        setupMarketsConfig(mockSequencerUptimeFeed, users.owner.account);
        configureLiquidationKeepers();

        vm.label({ account: mockChainlinkFeeManager, newLabel: "Chainlink Fee Manager" });
        vm.label({ account: mockChainlinkVerifier, newLabel: "Chainlink Verifier" });
        vm.label({ account: OFFCHAIN_ORDERS_KEEPER_ADDRESS, newLabel: "Offchain Orders Keeper" });

        // Market Making Engine Set Up

        address[] memory mmBranches = deployMarketMakingEngineBranches();

        bytes4[][] memory mmBranchesSelectors = getMarketMakerBranchesSelectors();
        RootProxy.BranchUpgrade[] memory mmBranchUpgrades =
            getBranchUpgrades(mmBranches, mmBranchesSelectors, RootProxy.BranchUpgradeAction.Add);

        mmBranchUpgrades = deployMarketMakingHarnesses(mmBranchUpgrades);

        address[] memory initializableBranches = new address[](0);
        bytes[] memory initializableBranchesPayloads = new bytes[](0);

        RootProxy.InitParams memory mmEngineInitParams = RootProxy.InitParams({
            initBranches: mmBranchUpgrades,
            initializables: initializableBranches,
            initializePayloads: initializableBranchesPayloads
        });

        marketMakingEngine = IMarketMakingEngine(address(new MarketMakingEngine(mmEngineInitParams)));

        uint256[2] memory vaultsIdsRange;
        vaultsIdsRange[0] = INITIAL_VAULT_ID;
        vaultsIdsRange[1] = FINAL_VAULT_ID;

        setupVaultsConfig();
        createZlpVaults(address(marketMakingEngine), users.owner.account, vaultsIdsRange);

        // Other Set Up
        approveContracts();
        changePrank({ msgSender: users.naruto.account });
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Generates a user, labels its address, and funds it with test assets.
    function createUser(string memory name) internal returns (User memory) {
        (address account, uint256 privateKey) = makeAddrAndKey(name);
        vm.deal({ account: account, newBalance: 100 ether });

        return User({ account: payable(account), privateKey: privateKey });
    }

    /// @dev Approves all Zaros contracts to spend the test assets.
    function approveContracts() internal {
        for (uint256 i = INITIAL_MARGIN_COLLATERAL_ID; i <= FINAL_MARGIN_COLLATERAL_ID; i++) {
            changePrank({ msgSender: users.naruto.account });
            IERC20(marginCollaterals[i].marginCollateralAddress).approve({
                spender: address(perpsEngine),
                value: uMAX_UD60x18
            });
            IERC20(marginCollaterals[i].marginCollateralAddress).approve({
                spender: address(marketMakingEngine),
                value: uMAX_UD60x18
            });

            changePrank({ msgSender: users.sasuke.account });
            IERC20(marginCollaterals[i].marginCollateralAddress).approve({
                spender: address(perpsEngine),
                value: uMAX_UD60x18
            });
            IERC20(marginCollaterals[i].marginCollateralAddress).approve({
                spender: address(marketMakingEngine),
                value: uMAX_UD60x18
            });

            changePrank({ msgSender: users.sakura.account });
            IERC20(marginCollaterals[i].marginCollateralAddress).approve({
                spender: address(perpsEngine),
                value: uMAX_UD60x18
            });
            IERC20(marginCollaterals[i].marginCollateralAddress).approve({
                spender: address(marketMakingEngine),
                value: uMAX_UD60x18
            });

            changePrank({ msgSender: users.madara.account });
            IERC20(marginCollaterals[i].marginCollateralAddress).approve({
                spender: address(perpsEngine),
                value: uMAX_UD60x18
            });
            IERC20(marginCollaterals[i].marginCollateralAddress).approve({
                spender: address(marketMakingEngine),
                value: uMAX_UD60x18
            });
        }

        changePrank({ msgSender: users.owner.account });
    }

    function configureContracts() internal {
        perpsEngine.setUsdToken(address(usdToken));
        perpsEngine.setTradingAccountToken(address(tradingAccountToken));

        tradingAccountToken.transferOwnership(address(perpsEngine));

        // TODO: Temporary, switch to Market Making engine
        usdToken.transferOwnership(address(perpsEngine));
    }

    function configureLiquidationKeepers() internal {
        changePrank({ msgSender: users.owner.account });
        liquidationKeeper =
            ChainlinkAutomationUtils.deployLiquidationKeeper(users.owner.account, address(perpsEngine));

        address[] memory liquidators = new address[](1);
        bool[] memory liquidatorStatus = new bool[](1);

        liquidators[0] = liquidationKeeper;
        liquidatorStatus[0] = true;

        perpsEngine.configureLiquidators(liquidators, liquidatorStatus);

        changePrank({ msgSender: users.naruto.account });
    }

    function configureSystemParameters() internal {
        perpsEngine.configureSystemParameters({
            maxPositionsPerAccount: MAX_POSITIONS_PER_ACCOUNT,
            marketOrderMinLifetime: MARKET_ORDER_MIN_LIFETIME,
            liquidationFeeUsdX18: LIQUIDATION_FEE_USD,
            marginCollateralRecipient: feeRecipients.marginCollateralRecipient,
            orderFeeRecipient: feeRecipients.orderFeeRecipient,
            settlementFeeRecipient: feeRecipients.settlementFeeRecipient,
            liquidationFeeRecipient: users.liquidationFeeRecipient.account,
            marketMakingEngine: address(marketMakingEngine),
            maxVerificationDelay: MAX_VERIFICATION_DELAY
        });
    }

    function createPerpMarkets() internal {
        createPerpMarkets(
            CreatePerpMarketsParams({
                deployer: users.owner.account,
                perpsEngine: perpsEngine,
                sequencerUptimeFeed: mockSequencerUptimeFeed,
                initialMarketId: INITIAL_MARKET_ID,
                finalMarketId: FINAL_MARKET_ID,
                chainlinkVerifier: IVerifierProxy(mockChainlinkVerifier),
                isTest: true
            })
        );

        for (uint256 i = INITIAL_MARKET_ID; i <= FINAL_MARKET_ID; i++) {
            vm.label({ account: marketOrderKeepers[i], newLabel: "Market Order Keeper" });
        }
    }

    function depositInVault(uint128 vaultId, uint128 assetsToDeposit) internal {
        address vaultAsset = marketMakingEngine.workaround_Vault_getVaultAsset(vaultId);
        deal(vaultAsset, users.naruto.account, assetsToDeposit);

        marketMakingEngine.deposit(vaultId, assetsToDeposit, 0);
    }

    function depositAndStakeInVault(uint128 vaultId, uint128 assetsToDeposit) internal {
        address vaultAsset = marketMakingEngine.workaround_Vault_getVaultAsset(vaultId);
        deal(vaultAsset, users.naruto.account, assetsToDeposit);

        marketMakingEngine.deposit(vaultId, assetsToDeposit, 0);

        address indexToken = marketMakingEngine.workaround_Vault_getIndexToken(vaultId);
        uint128 sharesToStake = IERC20(indexToken).balanceOf(users.naruto.account).toUint128();

        IERC20(indexToken).approve(address(marketMakingEngine), sharesToStake);
        marketMakingEngine.stake(vaultId, sharesToStake, new bytes(0), false);
    }

    function getFuzzVaultConfig(uint256 vaultId) internal view returns (VaultConfig memory) {
        vaultId = bound({ x: vaultId, min: INITIAL_VAULT_ID, max: FINAL_VAULT_ID });

        uint256[2] memory vaultIdsRange;
        vaultIdsRange[0] = vaultId;
        vaultIdsRange[1] = vaultId;

        VaultConfig[] memory filteredVaultsConfig = getFilteredVaultsConfig(vaultIdsRange);

        return filteredVaultsConfig[0];
    }

    function getFuzzMarketConfig(uint256 marketId) internal view returns (MarketConfig memory) {
        marketId = bound({ x: marketId, min: INITIAL_MARKET_ID, max: FINAL_MARKET_ID });

        uint256[2] memory marketsIdsRange;
        marketsIdsRange[0] = marketId;
        marketsIdsRange[1] = marketId;

        MarketConfig[] memory filteredMarketsConfig = getFilteredMarketsConfig(marketsIdsRange);

        return filteredMarketsConfig[0];
    }

    function getPrice(MockPriceFeed priceFeed) internal view returns (UD60x18) {
        uint8 decimals = priceFeed.decimals();
        (, int256 answer,,,) = priceFeed.latestRoundData();

        return ud60x18(uint256(answer) * 10 ** (SYSTEM_DECIMALS - decimals));
    }

    function convertTokenAmountToUd60x18(address collateralType, uint256 amount) internal view returns (UD60x18) {
        uint8 decimals = ERC20(collateralType).decimals();
        if (Constants.SYSTEM_DECIMALS == decimals) {
            return ud60x18(amount);
        }
        return ud60x18(amount * 10 ** (Constants.SYSTEM_DECIMALS - decimals));
    }

    function convertUd60x18ToTokenAmount(
        address collateralType,
        UD60x18 ud60x18Amount
    )
        internal
        view
        returns (uint256)
    {
        uint8 decimals = ERC20(collateralType).decimals();
        if (Constants.SYSTEM_DECIMALS == decimals) {
            return ud60x18Amount.intoUint256();
        }

        return ud60x18Amount.intoUint256() / (10 ** (Constants.SYSTEM_DECIMALS - decimals));
    }

    function getMockedSignedReport(
        bytes32 streamId,
        uint256 price
    )
        internal
        view
        returns (bytes memory mockedSignedReport)
    {
        bytes memory mockedReportData;

        PremiumReport memory premiumReport = PremiumReport({
            feedId: streamId,
            validFromTimestamp: uint32(block.timestamp),
            observationsTimestamp: uint32(block.timestamp),
            nativeFee: 0,
            linkFee: 0,
            expiresAt: uint32(block.timestamp + MOCK_DATA_STREAMS_EXPIRATION_DELAY),
            price: int192(int256(price)),
            bid: int192(int256(price)),
            ask: int192(int256(price))
        });

        mockedReportData = abi.encode(premiumReport);

        bytes32[3] memory mockedSignatures;
        mockedSignatures[0] = bytes32(uint256(keccak256(abi.encodePacked("mockedSignature1"))));
        mockedSignatures[1] = bytes32(uint256(keccak256(abi.encodePacked("mockedSignature2"))));
        mockedSignatures[2] = bytes32(uint256(keccak256(abi.encodePacked("mockedSignature3"))));

        mockedSignedReport = abi.encode(mockedSignatures, mockedReportData);
    }

    function getMockedSignedReportWithValidFromTimestampZero(
        bytes32 streamId,
        uint256 price
    )
        internal
        view
        returns (bytes memory mockedSignedReport)
    {
        bytes memory mockedReportData;

        PremiumReport memory premiumReport = PremiumReport({
            feedId: streamId,
            validFromTimestamp: 0,
            observationsTimestamp: uint32(block.timestamp),
            nativeFee: 0,
            linkFee: 0,
            expiresAt: uint32(block.timestamp + MOCK_DATA_STREAMS_EXPIRATION_DELAY),
            price: int192(int256(price)),
            bid: int192(int256(price)),
            ask: int192(int256(price))
        });

        mockedReportData = abi.encode(premiumReport);

        bytes32[3] memory mockedSignatures;
        mockedSignatures[0] = bytes32(uint256(keccak256(abi.encodePacked("mockedSignature1"))));
        mockedSignatures[1] = bytes32(uint256(keccak256(abi.encodePacked("mockedSignature2"))));
        mockedSignatures[2] = bytes32(uint256(keccak256(abi.encodePacked("mockedSignature3"))));

        mockedSignedReport = abi.encode(mockedSignatures, mockedReportData);
    }

    function createAccountAndDeposit(
        uint256 amount,
        address collateralType
    )
        internal
        returns (uint128 tradingAccountId)
    {
        tradingAccountId = perpsEngine.createTradingAccount(bytes(""), false);
        perpsEngine.depositMargin(tradingAccountId, collateralType, amount);
    }

    function updatePerpMarketMarginRequirements(uint128 marketId, UD60x18 newImr, UD60x18 newMmr) internal {
        PerpsEngineConfigurationBranch.UpdatePerpMarketConfigurationParams memory params =
        PerpsEngineConfigurationBranch.UpdatePerpMarketConfigurationParams({
            name: marketsConfig[marketId].marketName,
            symbol: marketsConfig[marketId].marketSymbol,
            priceAdapter: marketsConfig[marketId].priceAdapter,
            initialMarginRateX18: newImr.intoUint128(),
            maintenanceMarginRateX18: newMmr.intoUint128(),
            maxOpenInterest: marketsConfig[marketId].maxOi,
            maxSkew: marketsConfig[marketId].maxSkew,
            maxFundingVelocity: marketsConfig[marketId].maxFundingVelocity,
            minTradeSizeX18: marketsConfig[marketId].minTradeSize,
            skewScale: marketsConfig[marketId].skewScale,
            orderFees: marketsConfig[marketId].orderFees
        });

        perpsEngine.updatePerpMarketConfiguration(marketId, params);
    }

    function updatePerpMarketMaxOi(uint128 marketId, UD60x18 newMaxOi) internal {
        PerpsEngineConfigurationBranch.UpdatePerpMarketConfigurationParams memory params =
        PerpsEngineConfigurationBranch.UpdatePerpMarketConfigurationParams({
            name: marketsConfig[marketId].marketName,
            symbol: marketsConfig[marketId].marketSymbol,
            priceAdapter: marketsConfig[marketId].priceAdapter,
            initialMarginRateX18: marketsConfig[marketId].imr,
            maintenanceMarginRateX18: marketsConfig[marketId].mmr,
            maxOpenInterest: newMaxOi.intoUint128(),
            maxSkew: marketsConfig[marketId].maxSkew,
            maxFundingVelocity: marketsConfig[marketId].maxFundingVelocity,
            skewScale: marketsConfig[marketId].skewScale,
            minTradeSizeX18: marketsConfig[marketId].minTradeSize,
            orderFees: marketsConfig[marketId].orderFees
        });

        perpsEngine.updatePerpMarketConfiguration(marketId, params);
    }

    function updatePerpMarketMaxSkew(uint128 marketId, UD60x18 newMaxSkew) internal {
        PerpsEngineConfigurationBranch.UpdatePerpMarketConfigurationParams memory params =
        PerpsEngineConfigurationBranch.UpdatePerpMarketConfigurationParams({
            name: marketsConfig[marketId].marketName,
            symbol: marketsConfig[marketId].marketSymbol,
            priceAdapter: address(new MockPriceFeed(18, int256(marketsConfig[marketId].mockUsdPrice))),
            initialMarginRateX18: marketsConfig[marketId].imr,
            maintenanceMarginRateX18: marketsConfig[marketId].mmr,
            maxOpenInterest: marketsConfig[marketId].maxOi,
            maxSkew: newMaxSkew.intoUint128(),
            maxFundingVelocity: marketsConfig[marketId].maxFundingVelocity,
            skewScale: marketsConfig[marketId].skewScale,
            minTradeSizeX18: marketsConfig[marketId].minTradeSize,
            orderFees: marketsConfig[marketId].orderFees
        });

        perpsEngine.updatePerpMarketConfiguration(marketId, params);
    }

    function updateMockPriceFeed(uint128 marketId, uint256 newPrice) internal {
        MockPriceFeed priceFeed = MockPriceFeed(PriceAdapter(marketsConfig[marketId].priceAdapter).priceFeed());
        bool useEthPriceFeed = PriceAdapter(marketsConfig[marketId].priceAdapter).useEthPriceFeed();

        if (useEthPriceFeed) {
            UD60x18 mockEthUsdPrice = ud60x18(marketsConfig[ETH_USD_MARKET_ID].mockUsdPrice);
            UD60x18 mockSelectedMarketUsdPrice = ud60x18(newPrice);

            uint256 mockQuantityInEth = mockSelectedMarketUsdPrice.div(mockEthUsdPrice).intoUint256();

            priceFeed.updateMockPrice(mockQuantityInEth);
        } else {
            priceFeed.updateMockPrice(newPrice);
        }
    }

    struct FuzzOrderSizeDeltaParams {
        uint128 tradingAccountId;
        uint128 marketId;
        uint128 settlementConfigurationId;
        UD60x18 initialMarginRate;
        UD60x18 marginValueUsd;
        UD60x18 maxSkew;
        UD60x18 minTradeSize;
        UD60x18 price;
        bool isLong;
        bool shouldDiscountFees;
    }

    struct FuzzOrderSizeDeltaContext {
        int128 sizeDeltaPrePriceImpact;
        int128 sizeDeltaAbs;
        UD60x18 fuzzedSizeDeltaAbs;
        UD60x18 sizeDeltaWithPriceImpact;
        UD60x18 totalOrderFeeInSize;
    }

    function fuzzOrderSizeDelta(FuzzOrderSizeDeltaParams memory params) internal view returns (int128 sizeDelta) {
        FuzzOrderSizeDeltaContext memory ctx;

        if (params.marginValueUsd.gt(ud60x18(LIQUIDATION_FEE_USD))) {
            params.marginValueUsd = params.marginValueUsd.sub(ud60x18(LIQUIDATION_FEE_USD));
        }

        ctx.fuzzedSizeDeltaAbs = params.marginValueUsd.div(params.initialMarginRate).div(params.price);
        ctx.sizeDeltaAbs = Math.min(Math.max(ctx.fuzzedSizeDeltaAbs, params.minTradeSize), params.maxSkew).intoSD59x18(
        ).intoInt256().toInt128();
        ctx.sizeDeltaPrePriceImpact = params.isLong ? ctx.sizeDeltaAbs : -ctx.sizeDeltaAbs;

        (,,, UD60x18 orderFeeUsdX18, UD60x18 settlementFeeUsdX18, UD60x18 fillPriceX18) = perpsEngine.simulateTrade(
            OrderBranch.SimulateTradeParams({
                tradingAccountId: params.tradingAccountId,
                marketId: params.marketId,
                settlementConfigurationId: params.settlementConfigurationId,
                sizeDelta: ctx.sizeDeltaPrePriceImpact
            })
        );

        ctx.totalOrderFeeInSize = Math.divUp(orderFeeUsdX18.add(settlementFeeUsdX18), fillPriceX18);
        ctx.sizeDeltaWithPriceImpact = Math.min(
            (params.price.div(fillPriceX18).intoSD59x18().mul(sd59x18(ctx.sizeDeltaPrePriceImpact))).abs().intoUD60x18(
            ),
            params.maxSkew
        );

        // if testing revert  cases where we don't want to discount fees, we pass shouldDiscountFees as false
        sizeDelta = (
            params.isLong
                ? Math.max(
                    params.shouldDiscountFees
                        ? ctx.sizeDeltaWithPriceImpact.intoSD59x18().sub(
                            ctx.totalOrderFeeInSize.intoSD59x18().div(params.initialMarginRate.intoSD59x18())
                        )
                        : ctx.sizeDeltaWithPriceImpact.intoSD59x18(),
                    params.minTradeSize.intoSD59x18()
                )
                : Math.min(
                    params.shouldDiscountFees
                        ? unary(ctx.sizeDeltaWithPriceImpact.intoSD59x18()).add(
                            ctx.totalOrderFeeInSize.intoSD59x18().div(params.initialMarginRate.intoSD59x18())
                        )
                        : unary(ctx.sizeDeltaWithPriceImpact.intoSD59x18()),
                    unary(params.minTradeSize.intoSD59x18())
                )
        ).intoInt256().toInt128();
    }

    function openPosition(
        MarketConfig memory fuzzMarketConfig,
        uint128 tradingAccountId,
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong
    )
        internal
    {
        address marketOrderKeeper = marketOrderKeepers[fuzzMarketConfig.marketId];

        deal({ token: address(usdToken), to: users.naruto.account, give: marginValueUsd });

        int128 sizeDelta = fuzzOrderSizeDelta(
            FuzzOrderSizeDeltaParams({
                tradingAccountId: tradingAccountId,
                marketId: fuzzMarketConfig.marketId,
                settlementConfigurationId: SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
                initialMarginRate: ud60x18(initialMarginRate),
                marginValueUsd: ud60x18(marginValueUsd),
                maxSkew: ud60x18(fuzzMarketConfig.maxSkew),
                minTradeSize: ud60x18(fuzzMarketConfig.minTradeSize),
                price: ud60x18(fuzzMarketConfig.mockUsdPrice),
                isLong: isLong,
                shouldDiscountFees: true
            })
        );

        // first market order
        perpsEngine.createMarketOrder(
            OrderBranch.CreateMarketOrderParams({
                tradingAccountId: tradingAccountId,
                marketId: fuzzMarketConfig.marketId,
                sizeDelta: sizeDelta
            })
        );

        bytes memory mockSignedReport =
            getMockedSignedReport(fuzzMarketConfig.streamId, fuzzMarketConfig.mockUsdPrice);

        changePrank({ msgSender: marketOrderKeeper });

        // fill first order and open position
        perpsEngine.fillMarketOrder(tradingAccountId, fuzzMarketConfig.marketId, mockSignedReport);

        changePrank({ msgSender: users.naruto.account });
    }

    function setAccountsAsLiquidatable(MarketConfig memory fuzzMarketConfig, bool isLong) internal {
        uint256 priceShiftBps = ud60x18(fuzzMarketConfig.mmr).mul(ud60x18(1.25e18)).intoUint256();
        uint256 newIndexPrice = isLong
            ? ud60x18(fuzzMarketConfig.mockUsdPrice).mul(ud60x18(1e18).sub(ud60x18(priceShiftBps))).intoUint256()
            : ud60x18(fuzzMarketConfig.mockUsdPrice).mul(ud60x18(1e18).add(ud60x18(priceShiftBps))).intoUint256();

        updateMockPriceFeed(fuzzMarketConfig.marketId, newIndexPrice);
    }

    function openManualPosition(
        uint128 marketId,
        bytes32 streamId,
        uint256 mockUsdPrice,
        uint128 tradingAccountId,
        int128 sizeDelta
    )
        internal
    {
        perpsEngine.createMarketOrder(
            OrderBranch.CreateMarketOrderParams({
                tradingAccountId: tradingAccountId,
                marketId: marketId,
                sizeDelta: sizeDelta
            })
        );

        bytes memory mockSignedReport = getMockedSignedReport(streamId, mockUsdPrice);
        changePrank({ msgSender: marketOrderKeepers[marketId] });
        // fill first order and open position
        perpsEngine.fillMarketOrder(tradingAccountId, marketId, mockSignedReport);
        changePrank({ msgSender: users.naruto.account });
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
