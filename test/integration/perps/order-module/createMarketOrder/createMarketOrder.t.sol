// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { IOrderBranch } from "@zaros/perpetuals/interfaces/IOrderBranch.sol";
import { MarketOrder } from "@zaros/perpetuals/leaves/MarketOrder.sol";
import { SettlementConfiguration } from "@zaros/perpetuals/leaves/SettlementConfiguration.sol";
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";

// Open Zeppelin dependencies
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18, UNIT as UD_UNIT } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, unary } from "@prb-math/SD59x18.sol";

import { console } from "forge-std/console.sol";

contract CreateMarketOrder_Integration_Test is Base_Integration_Shared_Test {
    using SafeCast for int256;

    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();

        createPerpMarkets();

        changePrank({ msgSender: users.naruto });
    }

    function testFuzz_RevertGiven_TheAccountIdDoesNotExist(
        uint128 perpsAccountId,
        int128 sizeDelta,
        uint256 marketId
    )
        external
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.AccountNotFound.selector, perpsAccountId, users.naruto)
        });
        perpsEngine.createMarketOrder(
            IOrderBranch.CreateMarketOrderParams({
                accountId: perpsAccountId,
                marketId: fuzzMarketConfig.marketId,
                sizeDelta: sizeDelta
            })
        );
    }

    modifier givenTheAccountIdExists() {
        _;
    }

    function testFuzz_RevertGiven_TheSenderIsNotAuthorized(
        int128 sizeDelta,
        uint256 marketId
    )
        external
        givenTheAccountIdExists
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        uint128 perpsAccountId = perpsEngine.createPerpsAccount();

        changePrank({ msgSender: users.sasuke });

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.AccountPermissionDenied.selector, perpsAccountId, users.sasuke)
        });
        perpsEngine.createMarketOrder(
            IOrderBranch.CreateMarketOrderParams({
                accountId: perpsAccountId,
                marketId: fuzzMarketConfig.marketId,
                sizeDelta: sizeDelta
            })
        );
    }

    modifier givenTheSenderIsAuthorized() {
        _;
    }

    function test_RevertWhen_TheSizeDeltaIsZero(uint256 marketId)
        external
        givenTheAccountIdExists
        givenTheSenderIsAuthorized
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        uint128 perpsAccountId = perpsEngine.createPerpsAccount();

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "sizeDelta") });
        perpsEngine.createMarketOrder(
            IOrderBranch.CreateMarketOrderParams({
                accountId: perpsAccountId,
                marketId: fuzzMarketConfig.marketId,
                sizeDelta: 0
            })
        );
    }

    modifier whenTheSizeDeltaIsNotZero() {
        _;
    }

    function testFuzz_RevertGiven_ThePerpMarketIsDisabled(
        uint256 initialMarginRate,
        uint256 initialMarketId,
        uint256 initialMarginValueUsd,
        uint256 quantityFuzzMarginProfile,
        bool isLong
    )
        external
        givenTheAccountIdExists
        givenTheSenderIsAuthorized
        whenTheSizeDeltaIsNotZero
    {
        FuzzMarginProfile[] memory fuzzMarginProfiles = getFuzzMarginProfiles(
            quantityFuzzMarginProfile, initialMarketId, initialMarginRate, initialMarginValueUsd
        );

        for (uint256 i = 0; i < fuzzMarginProfiles.length; i++) {
            FuzzMarginProfile memory marginProfile = fuzzMarginProfiles[i];

            deal({ token: address(usdToken), to: users.naruto, give: marginProfile.marginValueUsd });

            uint128 perpsAccountId = createAccountAndDeposit(marginProfile.marginValueUsd, address(usdToken));
            int128 sizeDelta = fuzzOrderSizeDelta(
                FuzzOrderSizeDeltaParams({
                    accountId: perpsAccountId,
                    marketId: marginProfile.marketConfig.marketId,
                    settlementConfigurationId: SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
                    initialMarginRate: ud60x18(marginProfile.marginRate),
                    marginValueUsd: ud60x18(marginProfile.marginValueUsd),
                    maxOpenInterest: ud60x18(marginProfile.marketConfig.maxOi),
                    minTradeSize: ud60x18(marginProfile.marketConfig.minTradeSize),
                    price: ud60x18(marginProfile.marketConfig.mockUsdPrice),
                    isLong: isLong,
                    shouldDiscountFees: true
                })
            );

            changePrank({ msgSender: users.owner });
            perpsEngine.updatePerpMarketStatus({ marketId: marginProfile.marketConfig.marketId, enable: false });

            changePrank({ msgSender: users.naruto });

            vm.expectRevert({
                revertData: abi.encodeWithSelector(
                    Errors.PerpMarketDisabled.selector, marginProfile.marketConfig.marketId
                )
            });
            perpsEngine.createMarketOrder(
                IOrderBranch.CreateMarketOrderParams({
                    accountId: perpsAccountId,
                    marketId: marginProfile.marketConfig.marketId,
                    sizeDelta: sizeDelta
                })
            );
        }
    }

    modifier givenThePerpMarketIsEnabled() {
        _;
    }

    function testFuzz_RevertWhen_TheSizeDeltaIsLessThanTheMinTradeSize(
        uint256 initialMarginValueUsd,
        bool isLong,
        uint256 initialMarketId,
        uint256 quantityFuzzMarginProfile
    )
        external
        givenTheAccountIdExists
        givenTheSenderIsAuthorized
        whenTheSizeDeltaIsNotZero
        givenThePerpMarketIsEnabled
    {
        FuzzMarginProfile[] memory fuzzMarginProfiles =
            getFuzzMarginProfiles(quantityFuzzMarginProfile, initialMarketId, 0, initialMarginValueUsd);

        for (uint256 i = 0; i < fuzzMarginProfiles.length; i++) {
            FuzzMarginProfile memory marginProfile = fuzzMarginProfiles[i];

            deal({ token: address(usdToken), to: users.naruto, give: marginProfile.marginValueUsd });
            SD59x18 sizeDeltaAbs = ud60x18(marginProfile.marketConfig.minTradeSize).intoSD59x18().sub(sd59x18(1));

            int128 sizeDelta =
                isLong ? sizeDeltaAbs.intoInt256().toInt128() : unary(sizeDeltaAbs).intoInt256().toInt128();
            uint128 perpsAccountId = createAccountAndDeposit(marginProfile.marginValueUsd, address(usdToken));

            // it should revert
            vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.TradeSizeTooSmall.selector) });
            perpsEngine.createMarketOrder(
                IOrderBranch.CreateMarketOrderParams({
                    accountId: perpsAccountId,
                    marketId: marginProfile.marketConfig.marketId,
                    sizeDelta: sizeDelta
                })
            );
        }
    }

    modifier whenTheSizeDeltaIsGreaterThanTheMinTradeSize() {
        _;
    }

    function testFuzz_RevertGiven_ThePerpMarketWillReachTheOILimit(
        uint256 initialMarginValueUsd,
        bool isLong,
        uint256 initialMarketId,
        uint256 quantityFuzzMarginProfile
    )
        external
        givenTheAccountIdExists
        givenTheSenderIsAuthorized
        whenTheSizeDeltaIsNotZero
        givenThePerpMarketIsEnabled
        whenTheSizeDeltaIsGreaterThanTheMinTradeSize
    {
        FuzzMarginProfile[] memory fuzzMarginProfiles =
            getFuzzMarginProfiles(quantityFuzzMarginProfile, initialMarketId, 0, initialMarginValueUsd);

        for (uint256 i = 0; i < fuzzMarginProfiles.length; i++) {
            FuzzMarginProfile memory marginProfile = fuzzMarginProfiles[i];

            deal({ token: address(usdToken), to: users.naruto, give: initialMarginValueUsd });
            SD59x18 sizeDeltaAbs = ud60x18(marginProfile.marketConfig.maxOi).intoSD59x18().add(sd59x18(1));

            int128 sizeDelta =
                isLong ? sizeDeltaAbs.intoInt256().toInt128() : unary(sizeDeltaAbs).intoInt256().toInt128();
            uint128 perpsAccountId = createAccountAndDeposit(marginProfile.marginValueUsd, address(usdToken));

            // it should revert
            vm.expectRevert({
                revertData: abi.encodeWithSelector(
                    Errors.ExceedsOpenInterestLimit.selector,
                    marginProfile.marketConfig.marketId,
                    marginProfile.marketConfig.maxOi,
                    sizeDeltaAbs.intoUint256()
                )
            });
            perpsEngine.createMarketOrder(
                IOrderBranch.CreateMarketOrderParams({
                    accountId: perpsAccountId,
                    marketId: marginProfile.marketConfig.marketId,
                    sizeDelta: sizeDelta
                })
            );
        }
    }

    modifier givenThePerpMarketWontReachTheOILimit() {
        _;
    }

    function testFuzz_RevertGiven_TheAccountHasReachedThePositionsLimit(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong,
        uint256 marketId
    )
        external
        givenTheAccountIdExists
        givenTheSenderIsAuthorized
        whenTheSizeDeltaIsNotZero
        givenThePerpMarketIsEnabled
        whenTheSizeDeltaIsGreaterThanTheMinTradeSize
        givenThePerpMarketWontReachTheOILimit
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);
        MarketConfig memory secondFuzzMarketConfig;

        {
            uint256 secondMarketId = fuzzMarketConfig.marketId < FINAL_MARKET_ID
                ? fuzzMarketConfig.marketId + 1
                : fuzzMarketConfig.marketId - 1;

            uint256[2] memory marketsIdsRange;
            marketsIdsRange[0] = secondMarketId;
            marketsIdsRange[1] = secondMarketId;

            secondFuzzMarketConfig = getFilteredMarketsConfig(marketsIdsRange)[0];
        }

        initialMarginRate = bound({
            x: initialMarginRate,
            min: fuzzMarketConfig.marginRequirements + secondFuzzMarketConfig.marginRequirements,
            max: MAX_MARGIN_REQUIREMENTS * 2
        });
        marginValueUsd = bound({ x: marginValueUsd, min: USDZ_MIN_DEPOSIT_MARGIN, max: USDZ_DEPOSIT_CAP });

        deal({ token: address(usdToken), to: users.naruto, give: marginValueUsd });
        uint128 perpsAccountId = createAccountAndDeposit(marginValueUsd, address(usdToken));
        int128 firstOrderSizeDelta = fuzzOrderSizeDelta(
            FuzzOrderSizeDeltaParams({
                accountId: perpsAccountId,
                marketId: fuzzMarketConfig.marketId,
                settlementConfigurationId: SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
                initialMarginRate: ud60x18(initialMarginRate),
                marginValueUsd: ud60x18(marginValueUsd),
                maxOpenInterest: ud60x18(fuzzMarketConfig.maxOi),
                minTradeSize: ud60x18(fuzzMarketConfig.minTradeSize),
                price: ud60x18(fuzzMarketConfig.mockUsdPrice),
                isLong: isLong,
                shouldDiscountFees: true
            })
        );

        changePrank({ msgSender: users.owner });
        perpsEngine.configureSystemParameters({
            maxPositionsPerAccount: 1,
            marketOrderMaxLifetime: MARKET_ORDER_MAX_LIFETIME,
            liquidationFeeUsdX18: LIQUIDATION_FEE_USD
        });

        changePrank({ msgSender: users.naruto });

        perpsEngine.createMarketOrder(
            IOrderBranch.CreateMarketOrderParams({
                accountId: perpsAccountId,
                marketId: fuzzMarketConfig.marketId,
                sizeDelta: firstOrderSizeDelta
            })
        );

        changePrank({ msgSender: marketOrderKeepers[fuzzMarketConfig.marketId] });
        bytes memory mockSignedReport =
            getMockedSignedReport(fuzzMarketConfig.streamId, fuzzMarketConfig.mockUsdPrice);

        console.log(feeRecipients.marginCollateralRecipient);
        console.log(feeRecipients.orderFeeRecipient);
        console.log(feeRecipients.settlementFeeRecipient);
        perpsEngine.fillMarketOrder(perpsAccountId, fuzzMarketConfig.marketId, feeRecipients, mockSignedReport);

        changePrank({ msgSender: users.naruto });

        int128 secondOrderSizeDelta = fuzzOrderSizeDelta(
            FuzzOrderSizeDeltaParams({
                accountId: perpsAccountId,
                marketId: secondFuzzMarketConfig.marketId,
                settlementConfigurationId: SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
                initialMarginRate: ud60x18(initialMarginRate),
                marginValueUsd: ud60x18(marginValueUsd),
                maxOpenInterest: ud60x18(secondFuzzMarketConfig.maxOi),
                minTradeSize: ud60x18(secondFuzzMarketConfig.minTradeSize),
                price: ud60x18(secondFuzzMarketConfig.mockUsdPrice),
                isLong: isLong,
                shouldDiscountFees: true
            })
        );

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.MaxPositionsPerAccountReached.selector, perpsAccountId, 1, 1)
        });
        perpsEngine.createMarketOrder(
            IOrderBranch.CreateMarketOrderParams({
                accountId: perpsAccountId,
                marketId: secondFuzzMarketConfig.marketId,
                sizeDelta: secondOrderSizeDelta
            })
        );
    }

    modifier givenTheAccountHasNotReachedThePositionsLimit() {
        _;
    }

    function testFuzz_RevertGiven_TheAccountWontMeetTheMarginRequirement(
        uint256 initialMarginValueUsd,
        uint256 initialMarginRate,
        bool isLong,
        uint256 initialMarketId,
        uint256 quantityFuzzMarginProfile
    )
        external
        givenTheAccountIdExists
        givenTheSenderIsAuthorized
        whenTheSizeDeltaIsNotZero
        givenThePerpMarketIsEnabled
        whenTheSizeDeltaIsGreaterThanTheMinTradeSize
        givenThePerpMarketWontReachTheOILimit
        givenTheAccountHasNotReachedThePositionsLimit
    {
        FuzzMarginProfile[] memory fuzzMarginProfiles = getFuzzMarginProfiles(
            quantityFuzzMarginProfile, initialMarketId, initialMarginRate, initialMarginValueUsd
        );

        for (uint256 i = 0; i < fuzzMarginProfiles.length; i++) {
            FuzzMarginProfile memory marginProfile = fuzzMarginProfiles[i];

            UD60x18 adjustedMarginRequirements =
                ud60x18(marginProfile.marketConfig.marginRequirements).mul(ud60x18(0.9e18));
            UD60x18 maxMarginValueUsd = adjustedMarginRequirements.mul(ud60x18(marginProfile.marketConfig.maxOi)).mul(
                ud60x18(marginProfile.marketConfig.mockUsdPrice)
            );

            initialMarginValueUsd = bound({
                x: marginProfile.marginValueUsd,
                min: USDZ_MIN_DEPOSIT_MARGIN,
                max: maxMarginValueUsd.intoUint256()
            });
            initialMarginRate =
                bound({ x: marginProfile.marginRate, min: 1, max: adjustedMarginRequirements.intoUint256() });

            deal({ token: address(usdToken), to: users.naruto, give: initialMarginValueUsd });

            uint128 perpsAccountId = createAccountAndDeposit(initialMarginValueUsd, address(usdToken));
            int128 sizeDelta = fuzzOrderSizeDelta(
                FuzzOrderSizeDeltaParams({
                    accountId: perpsAccountId,
                    marketId: marginProfile.marketConfig.marketId,
                    settlementConfigurationId: SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
                    initialMarginRate: ud60x18(initialMarginRate),
                    marginValueUsd: ud60x18(initialMarginValueUsd),
                    maxOpenInterest: ud60x18(marginProfile.marketConfig.maxOi),
                    minTradeSize: ud60x18(marginProfile.marketConfig.minTradeSize),
                    price: ud60x18(marginProfile.marketConfig.mockUsdPrice),
                    isLong: isLong,
                    shouldDiscountFees: false
                })
            );

            (
                SD59x18 marginBalanceUsdX18,
                UD60x18 requiredInitialMarginUsdX18,
                UD60x18 requiredMaintenanceMarginUsdX18,
                SD59x18 orderFeeUsdX18,
                UD60x18 settlementFeeUsdX18,
            ) = perpsEngine.simulateTrade(
                perpsAccountId,
                marginProfile.marketConfig.marketId,
                SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
                sizeDelta
            );

            // it should revert
            vm.expectRevert({
                revertData: abi.encodeWithSelector(
                    Errors.InsufficientMargin.selector,
                    perpsAccountId,
                    marginBalanceUsdX18.intoInt256(),
                    requiredInitialMarginUsdX18.add(requiredMaintenanceMarginUsdX18).intoUint256(),
                    orderFeeUsdX18.add(settlementFeeUsdX18.intoSD59x18()).intoInt256()
                )
            });
            perpsEngine.createMarketOrder(
                IOrderBranch.CreateMarketOrderParams({
                    accountId: perpsAccountId,
                    marketId: marginProfile.marketConfig.marketId,
                    sizeDelta: sizeDelta
                })
            );
        }
    }

    modifier givenTheAccountWillMeetTheMarginRequirement() {
        _;
    }

    function testFuzz_RevertGiven_ThereIsAPendingMarketOrder(
        uint256 initialMarginRate,
        uint256 initialMarginValueUsd,
        bool isLong,
        uint256 initialMarketId,
        uint256 quantityFuzzMarginProfile
    )
        external
        givenTheAccountIdExists
        givenTheSenderIsAuthorized
        whenTheSizeDeltaIsNotZero
        givenThePerpMarketIsEnabled
        whenTheSizeDeltaIsGreaterThanTheMinTradeSize
        givenThePerpMarketWontReachTheOILimit
        givenTheAccountHasNotReachedThePositionsLimit
        givenTheAccountWillMeetTheMarginRequirement
    {
        FuzzMarginProfile[] memory fuzzMarginProfiles = getFuzzMarginProfiles(
            quantityFuzzMarginProfile, initialMarketId, initialMarginRate, initialMarginValueUsd
        );

        for (uint256 i = 0; i < fuzzMarginProfiles.length; i++) {
            FuzzMarginProfile memory marginProfile = fuzzMarginProfiles[i];

            deal({ token: address(usdToken), to: users.naruto, give: initialMarginValueUsd });

            uint128 perpsAccountId = createAccountAndDeposit(initialMarginValueUsd, address(usdToken));
            int128 sizeDelta = fuzzOrderSizeDelta(
                FuzzOrderSizeDeltaParams({
                    accountId: perpsAccountId,
                    marketId: marginProfile.marketConfig.marketId,
                    settlementConfigurationId: SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
                    initialMarginRate: ud60x18(marginProfile.marginRate),
                    marginValueUsd: ud60x18(marginProfile.marginValueUsd),
                    maxOpenInterest: ud60x18(marginProfile.marketConfig.maxOi),
                    minTradeSize: ud60x18(marginProfile.marketConfig.minTradeSize),
                    price: ud60x18(marginProfile.marketConfig.mockUsdPrice),
                    isLong: isLong,
                    shouldDiscountFees: true
                })
            );

            perpsEngine.createMarketOrder(
                IOrderBranch.CreateMarketOrderParams({
                    accountId: perpsAccountId,
                    marketId: marginProfile.marketConfig.marketId,
                    sizeDelta: sizeDelta
                })
            );

            // it should revert
            vm.expectRevert({
                revertData: abi.encodeWithSelector(Errors.MarketOrderStillPending.selector, block.timestamp)
            });
            perpsEngine.createMarketOrder(
                IOrderBranch.CreateMarketOrderParams({
                    accountId: perpsAccountId,
                    marketId: marginProfile.marketConfig.marketId,
                    sizeDelta: sizeDelta
                })
            );
        }
    }

    function testFuzz_GivenThereIsNoPendingMarketOrder(
        uint256 initialMarginRate,
        uint256 initialMarginValueUsd,
        bool isLong,
        uint256 initialMarketId,
        uint256 quantityFuzzMarginProfile
    )
        external
        givenTheAccountIdExists
        givenTheSenderIsAuthorized
        whenTheSizeDeltaIsNotZero
        givenThePerpMarketIsEnabled
        whenTheSizeDeltaIsGreaterThanTheMinTradeSize
        givenThePerpMarketWontReachTheOILimit
        givenTheAccountHasNotReachedThePositionsLimit
        givenTheAccountWillMeetTheMarginRequirement
    {
        FuzzMarginProfile[] memory fuzzMarginProfiles = getFuzzMarginProfiles(
            quantityFuzzMarginProfile, initialMarketId, initialMarginRate, initialMarginValueUsd
        );

        for (uint256 i = 0; i < fuzzMarginProfiles.length; i++) {
            FuzzMarginProfile memory marginProfile = fuzzMarginProfiles[i];

            deal({ token: address(usdToken), to: users.naruto, give: marginProfile.marginValueUsd });

            uint128 perpsAccountId = createAccountAndDeposit(marginProfile.marginValueUsd, address(usdToken));
            int128 sizeDelta = fuzzOrderSizeDelta(
                FuzzOrderSizeDeltaParams({
                    accountId: perpsAccountId,
                    marketId: marginProfile.marketConfig.marketId,
                    settlementConfigurationId: SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
                    initialMarginRate: ud60x18(marginProfile.marginRate),
                    marginValueUsd: ud60x18(marginProfile.marginValueUsd),
                    maxOpenInterest: ud60x18(marginProfile.marketConfig.maxOi),
                    minTradeSize: ud60x18(marginProfile.marketConfig.minTradeSize),
                    price: ud60x18(marginProfile.marketConfig.mockUsdPrice),
                    isLong: isLong,
                    shouldDiscountFees: true
                })
            );

            MarketOrder.Data memory expectedMarketOrder = MarketOrder.Data({
                marketId: marginProfile.marketConfig.marketId,
                sizeDelta: sizeDelta,
                timestamp: uint128(block.timestamp)
            });

            // it should emit a {LogCreateMarketOrder} event
            vm.expectEmit({ emitter: address(perpsEngine) });
            emit IOrderBranch.LogCreateMarketOrder(
                users.naruto, perpsAccountId, marginProfile.marketConfig.marketId, expectedMarketOrder
            );
            perpsEngine.createMarketOrder(
                IOrderBranch.CreateMarketOrderParams({
                    accountId: perpsAccountId,
                    marketId: marginProfile.marketConfig.marketId,
                    sizeDelta: sizeDelta
                })
            );

            // it should create the market order
            MarketOrder.Data memory marketOrder = perpsEngine.getActiveMarketOrder({ accountId: perpsAccountId });

            assertEq(marketOrder.sizeDelta, sizeDelta, "createMarketOrder: sizeDelta");
            assertEq(marketOrder.timestamp, block.timestamp, "createMarketOrder: timestamp");
        }
    }
}
