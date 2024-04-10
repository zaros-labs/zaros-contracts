// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { BasicReport } from "@zaros/external/chainlink/interfaces/IStreamsLookupCompatible.sol";
import { MarketOrder } from "@zaros/markets/perps/storage/MarketOrder.sol";
import { Position } from "@zaros/markets/perps/storage/Position.sol";
import { SettlementConfiguration } from "@zaros/markets/perps/storage/SettlementConfiguration.sol";
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";

// PRB Math dependencies
import { ud60x18 } from "@prb-math/UD60x18.sol";
import { sd59x18 } from "@prb-math/SD59x18.sol";

contract FillMarketOrder_Integration_Test is Base_Integration_Shared_Test {
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();
        createMarkets(initialMarketIndex, finalMarketIndex);
        changePrank({ msgSender: users.naruto });
    }

    function test_RevertGiven_TheSenderIsNotTheKeeper() external {
        // it should revert
    }

    modifier givenTheSenderIsTheKeeper() {
        _;
    }

    function test_RevertGiven_TheAccountDoesNotExist() external givenTheSenderIsTheKeeper {
        // it should revert
    }

    modifier givenTheAccountExists() {
        _;
    }

    function test_RevertGiven_ThePerpMarketIsDisabled() external givenTheSenderIsTheKeeper givenTheAccountExists {
        // it should revert
    }

    modifier givenThePerpMarketIsEnabled() {
        _;
    }

    function test_RevertWhen_TheSizeDeltaIsBelowTheMinimum()
        external
        givenTheSenderIsTheKeeper
        givenTheAccountExists
        givenThePerpMarketIsEnabled
    {
        // it should revert
    }

    modifier whenTheSizeDeltaIsAboveTheMinimum() {
        _;
    }

    function test_RevertGiven_TheSettlementStrategyIsDisabled()
        external
        givenTheSenderIsTheKeeper
        givenTheAccountExists
        givenThePerpMarketIsEnabled
        whenTheSizeDeltaIsAboveTheMinimum
    {
        // it should revert
    }

    modifier givenTheSettlementStrategyIsEnabled() {
        _;
    }

    function test_RevertGiven_TheSettlementStrategyDoesNotExist()
        external
        givenTheSenderIsTheKeeper
        givenTheAccountExists
        givenThePerpMarketIsEnabled
        whenTheSizeDeltaIsAboveTheMinimum
        givenTheSettlementStrategyIsEnabled
    {
        // it should revert
    }

    modifier givenTheSettlementStrategyExists() {
        _;
    }

    function test_RevertGiven_TheReportVerificationFails()
        external
        givenTheSenderIsTheKeeper
        givenTheAccountExists
        givenThePerpMarketIsEnabled
        whenTheSizeDeltaIsAboveTheMinimum
        givenTheSettlementStrategyIsEnabled
        givenTheSettlementStrategyExists
    {
        // it should revert
    }

    modifier givenTheReportVerificationPasses() {
        _;
    }

    function test_RevertGiven_TheDataStreamsReportIsInvalid()
        external
        givenTheSenderIsTheKeeper
        givenTheAccountExists
        givenThePerpMarketIsEnabled
        whenTheSizeDeltaIsAboveTheMinimum
        givenTheSettlementStrategyIsEnabled
        givenTheSettlementStrategyExists
        givenTheReportVerificationPasses
    {
        // it should revert
    }

    modifier givenTheDataStreamsReportIsValid() {
        _;
    }

    function test_RevertGiven_TheAccountWontMeetTheMarginRequirement()
        external
        givenTheSenderIsTheKeeper
        givenTheAccountExists
        givenThePerpMarketIsEnabled
        whenTheSizeDeltaIsAboveTheMinimum
        givenTheSettlementStrategyIsEnabled
        givenTheSettlementStrategyExists
        givenTheReportVerificationPasses
        givenTheDataStreamsReportIsValid
    {
        // it should revert
    }

    modifier givenTheAccountWillMeetTheMarginRequirement() {
        _;
    }

    function test_RevertGiven_TheMarketsOILimitWillBeExceeded()
        external
        givenTheSenderIsTheKeeper
        givenTheAccountExists
        givenThePerpMarketIsEnabled
        whenTheSizeDeltaIsAboveTheMinimum
        givenTheSettlementStrategyIsEnabled
        givenTheSettlementStrategyExists
        givenTheReportVerificationPasses
        givenTheDataStreamsReportIsValid
        givenTheAccountWillMeetTheMarginRequirement
    {
        // it should revert
    }

    function test_GivenTheMarketsOILimitWontBeExceeded()
        external
        givenTheSenderIsTheKeeper
        givenTheAccountExists
        givenThePerpMarketIsEnabled
        whenTheSizeDeltaIsAboveTheMinimum
        givenTheSettlementStrategyIsEnabled
        givenTheSettlementStrategyExists
        givenTheReportVerificationPasses
        givenTheDataStreamsReportIsValid
        givenTheAccountWillMeetTheMarginRequirement
    {
        // it should update the funding values
        // it should update the open interest and skew
        // it should update the account's active markets
        // it should update the account's position
        // it should apply the accrued pnl
        // it should emit a {LogSettleOrder} event
    }
}
