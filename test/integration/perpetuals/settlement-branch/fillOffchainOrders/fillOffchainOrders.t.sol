// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { IVerifierProxy } from "@zaros/external/chainlink/interfaces/IVerifierProxy.sol";
import { Constants } from "@zaros/utils/Constants.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { OffchainOrder } from "@zaros/perpetuals/leaves/OffchainOrder.sol";
import { SettlementConfiguration } from "@zaros/perpetuals/leaves/SettlementConfiguration.sol";
import { Base_Test } from "test/Base.t.sol";

// PRB Math dependencies
import { ud60x18 } from "@prb-math/UD60x18.sol";

contract FillOffchainOrders_Integration_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        configureSystemParameters();
        createPerpMarkets();
        changePrank({ msgSender: users.naruto.account });
    }

    function testFuzz_RevertGiven_TheSenderIsNotTheKeeper(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong,
        uint256 marketId,
        uint256 amountOfOrders
    )
        external
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        initialMarginRate = bound({ x: initialMarginRate, min: fuzzMarketConfig.imr, max: MAX_MARGIN_REQUIREMENTS });
        amountOfOrders = bound({ x: amountOfOrders, min: 1, max: 5 });
        marginValueUsd = bound({
            x: marginValueUsd,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18) / amountOfOrders
        });

        OffchainOrder.Data[] memory offchainOrders = new OffchainOrder.Data[](amountOfOrders);

        for (uint256 i = 0; i < amountOfOrders; i++) {
            deal({ token: address(usdc), to: users.naruto.account, give: marginValueUsd });
            uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdc));
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

            uint128 markPrice = perpsEngine.getMarkPrice(
                fuzzMarketConfig.marketId, fuzzMarketConfig.mockUsdPrice, sizeDelta
            ).intoUint128();

            offchainOrders[i] = OffchainOrder.Data({
                tradingAccountId: tradingAccountId,
                marketId: fuzzMarketConfig.marketId,
                sizeDelta: sizeDelta,
                targetPrice: markPrice,
                shouldIncreaseNonce: false,
                nonce: 0,
                salt: bytes32(0),
                v: 0,
                r: bytes32(0),
                s: bytes32(0)
            });
        }

        bytes memory mockSignedReport =
            getMockedSignedReport(fuzzMarketConfig.streamId, fuzzMarketConfig.mockUsdPrice);
        address offchainOrdersKeeper = OFFCHAIN_ORDERS_KEEPER_ADDRESS;

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.OnlyKeeper.selector, users.naruto.account, offchainOrdersKeeper)
        });
        perpsEngine.fillOffchainOrders(fuzzMarketConfig.marketId, offchainOrders, mockSignedReport);
    }

    modifier givenTheSenderIsTheKeeper() {
        _;
    }

    function testFuzz_RevertWhen_ThePriceDataIsNotValid(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong,
        uint256 marketId,
        uint256 amountOfOrders
    )
        external
        givenTheSenderIsTheKeeper
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        initialMarginRate = bound({ x: initialMarginRate, min: fuzzMarketConfig.imr, max: MAX_MARGIN_REQUIREMENTS });
        amountOfOrders = bound({ x: amountOfOrders, min: 1, max: 5 });
        marginValueUsd = bound({
            x: marginValueUsd,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18) / amountOfOrders
        });

        OffchainOrder.Data[] memory offchainOrders = new OffchainOrder.Data[](amountOfOrders);

        for (uint256 i = 0; i < amountOfOrders; i++) {
            deal({ token: address(usdc), to: users.naruto.account, give: marginValueUsd });
            uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdc));
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

            uint128 markPrice = perpsEngine.getMarkPrice(
                fuzzMarketConfig.marketId, fuzzMarketConfig.mockUsdPrice, sizeDelta
            ).intoUint128();

            offchainOrders[i] = OffchainOrder.Data({
                tradingAccountId: tradingAccountId,
                marketId: fuzzMarketConfig.marketId,
                sizeDelta: sizeDelta,
                targetPrice: markPrice,
                shouldIncreaseNonce: false,
                nonce: 0,
                salt: bytes32(0),
                v: 0,
                r: bytes32(0),
                s: bytes32(0)
            });
        }

        bytes memory mockSignedReport =
            getMockedSignedReport(fuzzMarketConfig.streamId, fuzzMarketConfig.mockUsdPrice);
        address offchainOrdersKeeper = OFFCHAIN_ORDERS_KEEPER_ADDRESS;

        SettlementConfiguration.DataStreamsStrategy memory offchainOrdersConfigurationData = SettlementConfiguration
            .DataStreamsStrategy({ chainlinkVerifier: IVerifierProxy(address(1)), streamId: fuzzMarketConfig.streamId });
        SettlementConfiguration.Data memory offchainOrdersConfiguration = SettlementConfiguration.Data({
            strategy: SettlementConfiguration.Strategy.DATA_STREAMS_DEFAULT,
            isEnabled: true,
            fee: DEFAULT_SETTLEMENT_FEE,
            keeper: offchainOrdersKeeper,
            data: abi.encode(offchainOrdersConfigurationData)
        });

        changePrank({ msgSender: users.owner.account });

        perpsEngine.updateSettlementConfiguration({
            marketId: fuzzMarketConfig.marketId,
            settlementConfigurationId: SettlementConfiguration.OFFCHAIN_ORDERS_CONFIGURATION_ID,
            newSettlementConfiguration: offchainOrdersConfiguration
        });

        changePrank({ msgSender: offchainOrdersKeeper });
        // it should revert
        vm.expectRevert();

        perpsEngine.fillOffchainOrders(fuzzMarketConfig.marketId, offchainOrders, mockSignedReport);
    }

    modifier whenThePriceDataIsValid() {
        _;
    }

    function testFuzz_RevertWhen_AnOffchainOrdersSizeDeltaIsZero(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong,
        uint256 marketId,
        uint256 amountOfOrders
    )
        external
        givenTheSenderIsTheKeeper
        whenThePriceDataIsValid
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        initialMarginRate = bound({ x: initialMarginRate, min: fuzzMarketConfig.imr, max: MAX_MARGIN_REQUIREMENTS });
        amountOfOrders = bound({ x: amountOfOrders, min: 1, max: 5 });
        marginValueUsd = bound({
            x: marginValueUsd,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18) / amountOfOrders
        });

        OffchainOrder.Data[] memory offchainOrders = new OffchainOrder.Data[](amountOfOrders + 1);

        for (uint256 i = 0; i < amountOfOrders; i++) {
            deal({ token: address(usdc), to: users.naruto.account, give: marginValueUsd });
            uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdc));
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

            uint128 markPrice = perpsEngine.getMarkPrice(
                fuzzMarketConfig.marketId, fuzzMarketConfig.mockUsdPrice, sizeDelta
            ).intoUint128();

            bytes32 salt = bytes32(block.prevrandao + i);

            bytes32 digest = keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    perpsEngine.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            Constants.CREATE_OFFCHAIN_ORDER_TYPEHASH,
                            tradingAccountId,
                            fuzzMarketConfig.marketId,
                            sizeDelta,
                            markPrice,
                            uint120(0),
                            false,
                            salt
                        )
                    )
                )
            );

            (uint8 v, bytes32 r, bytes32 s) = vm.sign({ privateKey: users.naruto.privateKey, digest: digest });

            offchainOrders[i] = OffchainOrder.Data({
                tradingAccountId: tradingAccountId,
                marketId: fuzzMarketConfig.marketId,
                sizeDelta: sizeDelta,
                targetPrice: markPrice,
                shouldIncreaseNonce: false,
                nonce: 0,
                salt: salt,
                v: v,
                r: r,
                s: s
            });
        }
        offchainOrders[offchainOrders.length - 1] = OffchainOrder.Data({
            tradingAccountId: 1,
            marketId: 0,
            sizeDelta: 0,
            targetPrice: 0,
            nonce: 0,
            shouldIncreaseNonce: false,
            salt: bytes32(0),
            v: 0,
            r: bytes32(0),
            s: bytes32(0)
        });

        bytes memory mockSignedReport =
            getMockedSignedReport(fuzzMarketConfig.streamId, fuzzMarketConfig.mockUsdPrice);
        address offchainOrdersKeeper = OFFCHAIN_ORDERS_KEEPER_ADDRESS;

        changePrank({ msgSender: offchainOrdersKeeper });
        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "offchainOrder.sizeDelta") });

        perpsEngine.fillOffchainOrders(fuzzMarketConfig.marketId, offchainOrders, mockSignedReport);
    }

    modifier whenAllOffchainOrdersHaveAValidSizeDelta() {
        _;
    }

    function testFuzz_RevertWhen_OneOfTheTradingAccountsDoesNotExist(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong,
        uint256 marketId,
        uint256 amountOfOrders
    )
        external
        givenTheSenderIsTheKeeper
        whenThePriceDataIsValid
        whenAllOffchainOrdersHaveAValidSizeDelta
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        initialMarginRate = bound({ x: initialMarginRate, min: fuzzMarketConfig.imr, max: MAX_MARGIN_REQUIREMENTS });
        amountOfOrders = bound({ x: amountOfOrders, min: 1, max: 5 });
        marginValueUsd = bound({
            x: marginValueUsd,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18) / amountOfOrders
        });

        OffchainOrder.Data[] memory offchainOrders = new OffchainOrder.Data[](amountOfOrders + 1);

        for (uint256 i = 0; i < amountOfOrders; i++) {
            deal({ token: address(usdc), to: users.naruto.account, give: marginValueUsd });
            uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdc));
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

            uint128 markPrice = perpsEngine.getMarkPrice(
                fuzzMarketConfig.marketId, fuzzMarketConfig.mockUsdPrice, sizeDelta
            ).intoUint128();

            bytes32 salt = bytes32(block.prevrandao + i);

            bytes32 digest = keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    perpsEngine.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            Constants.CREATE_OFFCHAIN_ORDER_TYPEHASH,
                            tradingAccountId,
                            fuzzMarketConfig.marketId,
                            sizeDelta,
                            markPrice,
                            uint120(0),
                            false,
                            salt
                        )
                    )
                )
            );

            (uint8 v, bytes32 r, bytes32 s) = vm.sign({ privateKey: users.naruto.privateKey, digest: digest });

            offchainOrders[i] = OffchainOrder.Data({
                tradingAccountId: tradingAccountId,
                marketId: fuzzMarketConfig.marketId,
                sizeDelta: sizeDelta,
                targetPrice: markPrice,
                shouldIncreaseNonce: false,
                nonce: 0,
                salt: salt,
                v: v,
                r: r,
                s: s
            });
        }
        offchainOrders[offchainOrders.length - 1] = OffchainOrder.Data({
            tradingAccountId: 0,
            marketId: 0,
            sizeDelta: 1,
            targetPrice: 0,
            nonce: 0,
            shouldIncreaseNonce: false,
            salt: bytes32(0),
            v: 0,
            r: bytes32(0),
            s: bytes32(0)
        });

        bytes memory mockSignedReport =
            getMockedSignedReport(fuzzMarketConfig.streamId, fuzzMarketConfig.mockUsdPrice);
        address offchainOrdersKeeper = OFFCHAIN_ORDERS_KEEPER_ADDRESS;

        changePrank({ msgSender: offchainOrdersKeeper });
        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.AccountNotFound.selector, 0, offchainOrdersKeeper)
        });

        perpsEngine.fillOffchainOrders(fuzzMarketConfig.marketId, offchainOrders, mockSignedReport);
    }

    modifier whenAllTradingAccountsExist() {
        _;
    }

    function testFuzz_RevertWhen_AnOffchainOrdersMarketIdIsNotEqualToTheProvidedMarketId(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong,
        uint256 marketId,
        uint256 amountOfOrders
    )
        external
        givenTheSenderIsTheKeeper
        whenThePriceDataIsValid
        whenAllOffchainOrdersHaveAValidSizeDelta
        whenAllTradingAccountsExist
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        initialMarginRate = bound({ x: initialMarginRate, min: fuzzMarketConfig.imr, max: MAX_MARGIN_REQUIREMENTS });
        amountOfOrders = bound({ x: amountOfOrders, min: 1, max: 5 });
        marginValueUsd = bound({
            x: marginValueUsd,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18) / amountOfOrders
        });

        OffchainOrder.Data[] memory offchainOrders = new OffchainOrder.Data[](amountOfOrders + 1);

        for (uint256 i = 0; i < amountOfOrders; i++) {
            deal({ token: address(usdc), to: users.naruto.account, give: marginValueUsd });
            uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdc));
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

            uint128 markPrice = perpsEngine.getMarkPrice(
                fuzzMarketConfig.marketId, fuzzMarketConfig.mockUsdPrice, sizeDelta
            ).intoUint128();

            bytes32 salt = bytes32(block.prevrandao + i);

            bytes32 digest = keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    perpsEngine.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            Constants.CREATE_OFFCHAIN_ORDER_TYPEHASH,
                            tradingAccountId,
                            fuzzMarketConfig.marketId,
                            sizeDelta,
                            markPrice,
                            uint120(0),
                            false,
                            salt
                        )
                    )
                )
            );

            (uint8 v, bytes32 r, bytes32 s) = vm.sign({ privateKey: users.naruto.privateKey, digest: digest });

            offchainOrders[i] = OffchainOrder.Data({
                tradingAccountId: tradingAccountId,
                marketId: fuzzMarketConfig.marketId,
                sizeDelta: sizeDelta,
                targetPrice: markPrice,
                shouldIncreaseNonce: false,
                nonce: 0,
                salt: salt,
                v: v,
                r: r,
                s: s
            });
        }
        offchainOrders[offchainOrders.length - 1] = OffchainOrder.Data({
            tradingAccountId: 1,
            marketId: 0,
            sizeDelta: 1,
            targetPrice: 0,
            nonce: 0,
            shouldIncreaseNonce: false,
            salt: bytes32(0),
            v: 0,
            r: bytes32(0),
            s: bytes32(0)
        });

        bytes memory mockSignedReport =
            getMockedSignedReport(fuzzMarketConfig.streamId, fuzzMarketConfig.mockUsdPrice);
        address offchainOrdersKeeper = OFFCHAIN_ORDERS_KEEPER_ADDRESS;

        changePrank({ msgSender: offchainOrdersKeeper });
        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.OrderMarketIdMismatch.selector, fuzzMarketConfig.marketId, 0)
        });

        perpsEngine.fillOffchainOrders(fuzzMarketConfig.marketId, offchainOrders, mockSignedReport);
    }

    modifier whenAnOffchainOrdersMarketIdIsEqualToTheProvidedMarketId() {
        _;
    }

    function testFuzz_RevertWhen_AnOffchainOrdersNonceIsNotEqualToTheTradingAccountsNonce(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong,
        uint256 marketId,
        uint256 amountOfOrders
    )
        external
        givenTheSenderIsTheKeeper
        whenThePriceDataIsValid
        whenAllOffchainOrdersHaveAValidSizeDelta
        whenAllTradingAccountsExist
        whenAnOffchainOrdersMarketIdIsEqualToTheProvidedMarketId
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        initialMarginRate = bound({ x: initialMarginRate, min: fuzzMarketConfig.imr, max: MAX_MARGIN_REQUIREMENTS });
        amountOfOrders = bound({ x: amountOfOrders, min: 1, max: 5 });
        marginValueUsd = bound({
            x: marginValueUsd,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18) / amountOfOrders
        });

        OffchainOrder.Data[] memory offchainOrders = new OffchainOrder.Data[](amountOfOrders + 1);

        for (uint256 i = 0; i < amountOfOrders; i++) {
            deal({ token: address(usdc), to: users.naruto.account, give: marginValueUsd });
            uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdc));
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

            uint128 markPrice = perpsEngine.getMarkPrice(
                fuzzMarketConfig.marketId, fuzzMarketConfig.mockUsdPrice, sizeDelta
            ).intoUint128();

            bytes32 salt = bytes32(block.prevrandao + i);

            bytes32 digest = keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    perpsEngine.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            Constants.CREATE_OFFCHAIN_ORDER_TYPEHASH,
                            tradingAccountId,
                            fuzzMarketConfig.marketId,
                            sizeDelta,
                            markPrice,
                            uint120(0),
                            false,
                            salt
                        )
                    )
                )
            );

            (uint8 v, bytes32 r, bytes32 s) = vm.sign({ privateKey: users.naruto.privateKey, digest: digest });

            offchainOrders[i] = OffchainOrder.Data({
                tradingAccountId: tradingAccountId,
                marketId: fuzzMarketConfig.marketId,
                sizeDelta: sizeDelta,
                targetPrice: markPrice,
                shouldIncreaseNonce: false,
                nonce: 0,
                salt: salt,
                v: v,
                r: r,
                s: s
            });
        }
        offchainOrders[offchainOrders.length - 1] = OffchainOrder.Data({
            tradingAccountId: 1,
            marketId: fuzzMarketConfig.marketId,
            sizeDelta: 1,
            targetPrice: 0,
            nonce: 1,
            shouldIncreaseNonce: false,
            salt: bytes32(0),
            v: 0,
            r: bytes32(0),
            s: bytes32(0)
        });

        bytes memory mockSignedReport =
            getMockedSignedReport(fuzzMarketConfig.streamId, fuzzMarketConfig.mockUsdPrice);
        address offchainOrdersKeeper = OFFCHAIN_ORDERS_KEEPER_ADDRESS;

        changePrank({ msgSender: offchainOrdersKeeper });
        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.InvalidSignedNonce.selector, 0, 1) });

        perpsEngine.fillOffchainOrders(fuzzMarketConfig.marketId, offchainOrders, mockSignedReport);
    }

    modifier whenAllOffchainOrdersNoncesAreEqualToTheTradingAccountsNonces() {
        _;
    }

    function testFuzz_RevertGiven_AnOffchainOrderHasAlreadyBeenFilled(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong,
        uint256 marketId,
        uint256 amountOfOrders
    )
        external
        givenTheSenderIsTheKeeper
        whenThePriceDataIsValid
        whenAllOffchainOrdersHaveAValidSizeDelta
        whenAllTradingAccountsExist
        whenAnOffchainOrdersMarketIdIsEqualToTheProvidedMarketId
        whenAllOffchainOrdersNoncesAreEqualToTheTradingAccountsNonces
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        initialMarginRate = bound({ x: initialMarginRate, min: fuzzMarketConfig.imr, max: MAX_MARGIN_REQUIREMENTS });
        amountOfOrders = bound({ x: amountOfOrders, min: 1, max: 5 });
        marginValueUsd = bound({
            x: marginValueUsd,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18) / amountOfOrders
        });

        OffchainOrder.Data[] memory offchainOrders = new OffchainOrder.Data[](amountOfOrders + 1);

        for (uint256 i = 0; i < amountOfOrders; i++) {
            deal({ token: address(usdc), to: users.naruto.account, give: marginValueUsd });
            uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdc));
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

            uint128 markPrice = perpsEngine.getMarkPrice(
                fuzzMarketConfig.marketId, fuzzMarketConfig.mockUsdPrice, sizeDelta
            ).intoUint128();

            bytes32 salt = bytes32(block.prevrandao + i);

            bytes32 digest = keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    perpsEngine.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            Constants.CREATE_OFFCHAIN_ORDER_TYPEHASH,
                            tradingAccountId,
                            fuzzMarketConfig.marketId,
                            sizeDelta,
                            markPrice,
                            uint120(0),
                            false,
                            salt
                        )
                    )
                )
            );

            (uint8 v, bytes32 r, bytes32 s) = vm.sign({ privateKey: users.naruto.privateKey, digest: digest });

            offchainOrders[i] = OffchainOrder.Data({
                tradingAccountId: tradingAccountId,
                marketId: fuzzMarketConfig.marketId,
                sizeDelta: sizeDelta,
                targetPrice: markPrice,
                shouldIncreaseNonce: false,
                nonce: 0,
                salt: salt,
                v: v,
                r: r,
                s: s
            });
        }
        offchainOrders[offchainOrders.length - 1] = OffchainOrder.Data({
            tradingAccountId: 1,
            marketId: fuzzMarketConfig.marketId,
            sizeDelta: 1,
            targetPrice: 0,
            nonce: 0,
            shouldIncreaseNonce: false,
            salt: bytes32(0),
            v: 0,
            r: bytes32(0),
            s: bytes32(0)
        });

        bytes memory mockSignedReport =
            getMockedSignedReport(fuzzMarketConfig.streamId, fuzzMarketConfig.mockUsdPrice);
        address offchainOrdersKeeper = OFFCHAIN_ORDERS_KEEPER_ADDRESS;

        changePrank({ msgSender: offchainOrdersKeeper });
        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.InvalidSignedNonce.selector, 0, 1) });

        perpsEngine.fillOffchainOrders(fuzzMarketConfig.marketId, offchainOrders, mockSignedReport);
    }

    modifier givenAllOffchainOrdersHaveNotBeenFilled() {
        _;
    }

    function test_RevertGiven_TheOrdersSignerIsNotTheTradingAccountOwner()
        external
        givenTheSenderIsTheKeeper
        whenThePriceDataIsValid
        whenAllOffchainOrdersHaveAValidSizeDelta
        whenAllTradingAccountsExist
        whenAnOffchainOrdersMarketIdIsEqualToTheProvidedMarketId
        whenAllOffchainOrdersNoncesAreEqualToTheTradingAccountsNonces
        givenAllOffchainOrdersHaveNotBeenFilled
    {
        // it should revert
    }

    modifier givenTheOrdersSignerIsTheTradingAccountOwner() {
        _;
    }

    function test_WhenAnOffchainOrdersTargetPriceCantBeMatchedWithItsFillPrice()
        external
        givenTheSenderIsTheKeeper
        whenThePriceDataIsValid
        whenAllOffchainOrdersHaveAValidSizeDelta
        whenAllTradingAccountsExist
        whenAnOffchainOrdersMarketIdIsEqualToTheProvidedMarketId
        whenAllOffchainOrdersNoncesAreEqualToTheTradingAccountsNonces
        givenAllOffchainOrdersHaveNotBeenFilled
        givenTheOrdersSignerIsTheTradingAccountOwner
    {
        // it should not fill that order
    }

    modifier whenAllOffchainOrdersTargetPriceCanBeMatchedWithItsFillPrice() {
        _;
    }

    function test_WhenTheOffchainOrderShouldIncreaseTheNonce()
        external
        givenTheSenderIsTheKeeper
        whenThePriceDataIsValid
        whenAllOffchainOrdersHaveAValidSizeDelta
        whenAllTradingAccountsExist
        whenAnOffchainOrdersMarketIdIsEqualToTheProvidedMarketId
        whenAllOffchainOrdersNoncesAreEqualToTheTradingAccountsNonces
        givenAllOffchainOrdersHaveNotBeenFilled
        givenTheOrdersSignerIsTheTradingAccountOwner
        whenAllOffchainOrdersTargetPriceCanBeMatchedWithItsFillPrice
    {
        // it should increase the trading account nonce
        // it should fill the offchain order
    }

    function test_WhenTheOffchainOrderShouldntIncreaseTheNonce()
        external
        givenTheSenderIsTheKeeper
        whenThePriceDataIsValid
        whenAllOffchainOrdersHaveAValidSizeDelta
        whenAllTradingAccountsExist
        whenAnOffchainOrdersMarketIdIsEqualToTheProvidedMarketId
        whenAllOffchainOrdersNoncesAreEqualToTheTradingAccountsNonces
        givenAllOffchainOrdersHaveNotBeenFilled
        givenTheOrdersSignerIsTheTradingAccountOwner
        whenAllOffchainOrdersTargetPriceCanBeMatchedWithItsFillPrice
    {
        // it should not increase the trading account nonce
        // it should fill the offchain order
    }
}
