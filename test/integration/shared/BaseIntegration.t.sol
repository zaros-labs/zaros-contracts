// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { BasicReport, PremiumReport } from "@zaros/external/chainlink/interfaces/IStreamsLookupCompatible.sol";
import { Constants } from "@zaros/utils/Constants.sol";
import { Base_Test } from "test/Base.t.sol";
import { MockPriceFeed } from "test/mocks/MockPriceFeed.sol";

// PRB Math dependencies
import { sd59x18 } from "@prb-math/SD59x18.sol";
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

abstract contract Base_Integration_Shared_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
    }

    function createAccountAndDeposit(uint256 amount, address collateralType) internal returns (uint128 accountId) {
        accountId = perpsEngine.createPerpsAccount();
        perpsEngine.depositMargin(accountId, collateralType, amount);
    }

    function configureSystemParameters() internal {
        perpsEngine.configureSystemParameters({
            maxPositionsPerAccount: MAX_POSITIONS_PER_ACCOUNT,
            marketOrderMaxLifetime: MARKET_ORDER_MAX_LIFETIME
        });
    }

    function createMarkets() internal {
        perpsEngine.createPerpsMarket(
            BTC_USD_MARKET_ID,
            BTC_USD_MARKET_NAME,
            BTC_USD_MARKET_SYMBOL,
            BTC_USD_MMR,
            BTC_USD_MAX_OI,
            BTC_USD_MIN_IMR,
            btcUsdMarketOrderStrategy,
            btcUsdCustomTriggerStrategies,
            btcUsdOrderFees
        );

        perpsEngine.createPerpsMarket(
            ETH_USD_MARKET_ID,
            ETH_USD_MARKET_NAME,
            ETH_USD_MARKET_SYMBOL,
            ETH_USD_MMR,
            ETH_USD_MAX_OI,
            ETH_USD_MIN_IMR,
            ethUsdMarketOrderStrategy,
            ethUsdCustomTriggerStrategies,
            ethUsdOrderFees
        );
    }

    function getPrice(MockPriceFeed priceFeed) internal view returns (UD60x18) {
        uint8 decimals = priceFeed.decimals();
        (, int256 answer,,,) = priceFeed.latestRoundData();

        return ud60x18(uint256(answer) * 10 ** (DEFAULT_DECIMALS - decimals));
    }

    function getMockedReportData(
        string memory streamId,
        uint256 price,
        bool isPremium
    )
        internal
        view
        returns (bytes memory reportData)
    {
        // TODO: We need to check at the perps engine level if the report's stream id is the market's one.
        bytes32 mockStreamIdBytes32 = bytes32(uint256(keccak256(abi.encodePacked(streamId))));
        if (isPremium) {
            PremiumReport memory premiumReport = PremiumReport({
                feedId: mockStreamIdBytes32,
                validFromTimestamp: uint32(block.timestamp),
                observationsTimestamp: uint32(block.timestamp),
                nativeFee: 0,
                linkFee: 0,
                expiresAt: uint32(block.timestamp + MOCK_DATA_STREAMS_EXPIRATION_DELAY),
                price: int192(int256(price)),
                bid: int192(int256(price)),
                ask: int192(int256(price))
            });
        } else {
            BasicReport memory basicReport = BasicReport({
                feedId: mockStreamIdBytes32,
                validFromTimestamp: uint32(block.timestamp),
                observationsTimestamp: uint32(block.timestamp),
                nativeFee: 0,
                linkFee: 0,
                expiresAt: uint32(block.timestamp + MOCK_DATA_STREAMS_EXPIRATION_DELAY),
                price: int192(int256(price))
            });
        }
    }

    function mockSettleMarketOrder(uint128 accountId, uint128 marketId, bytes memory extraData) internal {
        perpsEngine.settleMarketOrder(accountId, marketId, extraData);
    }
}
