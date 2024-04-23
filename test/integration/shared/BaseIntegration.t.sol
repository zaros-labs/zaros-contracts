// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { IVerifierProxy } from "@zaros/external/chainlink/interfaces/IVerifierProxy.sol";
import { MarketOrderKeeper } from "@zaros/external/chainlink/keepers/market-order/MarketOrderKeeper.sol";
import { IFeeManager } from "@zaros/external/chainlink/interfaces/IFeeManager.sol";
import { BasicReport, PremiumReport } from "@zaros/external/chainlink/interfaces/IStreamsLookupCompatible.sol";
import { Constants } from "@zaros/utils/Constants.sol";
import { Math } from "@zaros/utils/Math.sol";
import { IGlobalConfigurationModule } from "@zaros/markets/perps/interfaces/IGlobalConfigurationModule.sol";
import { OrderFees } from "@zaros/markets/perps/storage/OrderFees.sol";
import { SettlementConfiguration } from "@zaros/markets/perps/storage/SettlementConfiguration.sol";
import { Base_Test } from "test/Base.t.sol";
import { MockChainlinkFeeManager } from "test/mocks/MockChainlinkFeeManager.sol";
import { MockChainlinkVerifier } from "test/mocks/MockChainlinkVerifier.sol";
import { MockPriceFeed } from "test/mocks/MockPriceFeed.sol";

// Open Zeppelin dependencies
import { ERC1967Proxy } from "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import { ERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { SD59x18, sd59x18, unary } from "@prb-math/SD59x18.sol";
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

abstract contract Base_Integration_Shared_Test is Base_Test {
    using Math for UD60x18;
    using SafeCast for int256;

    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/
    address internal mockChainlinkFeeManager;
    address internal mockChainlinkVerifier;
    address internal settlementFeeReceiver = users.settlementFeeReceiver;
    mapping(uint256 marketId => address keeper) internal marketOrderKeepers;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/
    function setUp() public virtual override {
        Base_Test.setUp();

        mockChainlinkFeeManager = address(new MockChainlinkFeeManager());
        mockChainlinkVerifier = address(new MockChainlinkVerifier(IFeeManager(mockChainlinkFeeManager)));

        vm.label({ account: mockChainlinkFeeManager, newLabel: "Chainlink Fee Manager" });
        vm.label({ account: mockChainlinkVerifier, newLabel: "Chainlink Verifier" });
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

    function createAccountAndDeposit(uint256 amount, address collateralType) internal returns (uint128 accountId) {
        accountId = perpsEngine.createPerpsAccount();
        perpsEngine.depositMargin(accountId, collateralType, amount);
    }

    function configureSystemParameters() internal {
        perpsEngine.configureSystemParameters({
            maxPositionsPerAccount: MAX_POSITIONS_PER_ACCOUNT,
            marketOrderMaxLifetime: MARKET_ORDER_MAX_LIFETIME,
            liquidationFeeUsdX18: LIQUIDATION_FEE_USD
        });
    }

    function createMarkets() internal {
        uint256[] memory filteredIndexMarkets = new uint256[](2);
        filteredIndexMarkets[0] = INITIAL_MARKET_INDEX;
        filteredIndexMarkets[1] = FINAL_MARKET_INDEX;

        (MarketConfig[] memory marketsConfig) = getMarketsConfig(filteredIndexMarkets);
        address marketOrderKeeperImplementation = address(new MarketOrderKeeper());

        for (uint256 i = 0; i < marketsConfig.length; i++) {
            marketOrderKeepers[marketsConfig[i].marketId] = address(
                new ERC1967Proxy(
                    marketOrderKeeperImplementation,
                    abi.encodeWithSelector(
                        MarketOrderKeeper.initialize.selector,
                        users.owner,
                        perpsEngine,
                        users.settlementFeeReceiver,
                        marketsConfig[i].marketId,
                        marketsConfig[i].streamIdString
                    )
                )
            );
            vm.label({ account: marketOrderKeepers[marketsConfig[i].marketId], newLabel: "Market Order Keeper" });

            SettlementConfiguration.DataStreamsStrategy memory marketOrderConfigurationData = SettlementConfiguration
                .DataStreamsStrategy({
                chainlinkVerifier: IVerifierProxy(mockChainlinkVerifier),
                streamId: marketsConfig[i].streamId
            });
            SettlementConfiguration.Data memory marketOrderConfiguration = SettlementConfiguration.Data({
                strategy: SettlementConfiguration.Strategy.DATA_STREAMS_ONCHAIN,
                isEnabled: true,
                fee: DATA_STREAMS_SETTLEMENT_FEE,
                keeper: marketOrderKeepers[marketsConfig[i].marketId],
                data: abi.encode(marketOrderConfigurationData)
            });

            // TODO: update to API orderbook config
            SettlementConfiguration.Data[] memory customOrderStrategies;

            perpsEngine.createPerpMarket(
                IGlobalConfigurationModule.CreatePerpMarketParams({
                    marketId: marketsConfig[i].marketId,
                    name: marketsConfig[i].marketName,
                    symbol: marketsConfig[i].marketSymbol,
                    priceAdapter: address(new MockPriceFeed(18, int256(marketsConfig[i].mockUsdPrice))),
                    initialMarginRateX18: marketsConfig[i].imr,
                    maintenanceMarginRateX18: marketsConfig[i].mmr,
                    maxOpenInterest: marketsConfig[i].maxOi,
                    maxFundingVelocity: marketsConfig[i].maxFundingVelocity,
                    skewScale: marketsConfig[i].skewScale,
                    minTradeSizeX18: marketsConfig[i].minTradeSize,
                    marketOrderConfiguration: marketOrderConfiguration,
                    customOrderStrategies: customOrderStrategies,
                    orderFees: marketsConfig[i].orderFees
                })
            );
        }
    }

    function updatePerpMarketMarginRequirements(uint128 marketId, UD60x18 newImr, UD60x18 newMmr) internal {
        uint256[] memory filteredIndexMarkets = new uint256[](2);
        filteredIndexMarkets[0] = INITIAL_MARKET_INDEX;
        filteredIndexMarkets[1] = FINAL_MARKET_INDEX;

        (MarketConfig[] memory marketsConfig) = getMarketsConfig(filteredIndexMarkets);

        IGlobalConfigurationModule.UpdatePerpMarketConfigurationParams memory params = IGlobalConfigurationModule
            .UpdatePerpMarketConfigurationParams({
            marketId: marketId,
            name: marketsConfig[marketId].marketName,
            symbol: marketsConfig[marketId].marketSymbol,
            priceAdapter: address(new MockPriceFeed(18, int256(marketsConfig[marketId].mockUsdPrice))),
            initialMarginRateX18: newImr.intoUint128(),
            maintenanceMarginRateX18: newMmr.intoUint128(),
            maxOpenInterest: marketsConfig[marketId].maxOi,
            maxFundingVelocity: marketsConfig[marketId].maxFundingVelocity,
            skewScale: marketsConfig[marketId].skewScale,
            minTradeSizeX18: marketsConfig[marketId].minTradeSize,
            orderFees: marketsConfig[marketId].orderFees
        });
    }

    struct FuzzOrderSizeDeltaParams {
        uint128 accountId;
        uint128 marketId;
        uint128 settlementConfigurationId;
        UD60x18 initialMarginRate;
        UD60x18 marginValueUsd;
        UD60x18 maxOpenInterest;
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

        ctx.fuzzedSizeDeltaAbs = params.marginValueUsd.div(params.initialMarginRate).div(params.price);
        ctx.sizeDeltaAbs = Math.min(Math.max(ctx.fuzzedSizeDeltaAbs, params.minTradeSize), params.maxOpenInterest)
            .intoSD59x18().intoInt256().toInt128();
        ctx.sizeDeltaPrePriceImpact = params.isLong ? ctx.sizeDeltaAbs : -ctx.sizeDeltaAbs;

        (,,, SD59x18 orderFeeUsdX18, UD60x18 settlementFeeUsdX18, UD60x18 fillPriceX18) = perpsEngine.simulateTrade(
            params.accountId, params.marketId, params.settlementConfigurationId, ctx.sizeDeltaPrePriceImpact
        );

        ctx.totalOrderFeeInSize = Math.divUp(orderFeeUsdX18.intoUD60x18().add(settlementFeeUsdX18), fillPriceX18);
        ctx.sizeDeltaWithPriceImpact = Math.min(
            (params.price.div(fillPriceX18).intoSD59x18().mul(sd59x18(ctx.sizeDeltaPrePriceImpact))).abs().intoUD60x18(
            ),
            params.maxOpenInterest
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

    function getFuzzMarketConfig(uint256 marketIndex) internal pure returns (MarketConfig memory) {
        vm.assume(marketIndex >= INITIAL_MARKET_INDEX && marketIndex <= FINAL_MARKET_INDEX);

        uint256[] memory filteredIndexMarkets = new uint256[](2);
        filteredIndexMarkets[0] = marketIndex;
        filteredIndexMarkets[1] = marketIndex;

        (MarketConfig[] memory marketsConfig) = getMarketsConfig(filteredIndexMarkets);

        return marketsConfig[0];
    }
}
