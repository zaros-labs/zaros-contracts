// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { SettlementConfiguration } from "@zaros/perpetuals/leaves/TradingAccount.sol";
import { FeeRecipients } from "@zaros/perpetuals/leaves/FeeRecipients.sol";

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18 } from "@prb-math/SD59x18.sol";

contract SettlementConfigurationHarness {
    function exposed_load(
        uint128 marketId,
        uint128 settlementConfigurationId
    )
        external
        pure
        returns (SettlementConfiguration.Data memory)
    {
        return SettlementConfiguration.load(marketId, settlementConfigurationId);
    }

    function exposed_checkIsValidSettlementStrategy(
        uint128 settlementConfigurationId,
        SettlementConfiguration.Strategy strategy
    )
        external
        pure
    {
        SettlementConfiguration.checkIsValidSettlementStrategy(settlementConfigurationId, strategy);
    }

    function exposed_update(
        uint128 marketId,
        uint128 settlementConfigurationId,
        SettlementConfiguration.Data memory newSettlementConfiguration
    )
        external
    {
        SettlementConfiguration.update(marketId, settlementConfigurationId, newSettlementConfiguration);
    }

    function exposed_getDataStreamsReportPrice(
        bytes memory verifiedPriceData,
        bool isBuyOrder
    )
        external
        pure
        returns (UD60x18 price)
    {
        return SettlementConfiguration.getDataStreamsReportPrice(verifiedPriceData, isBuyOrder);
    }

    function exposed_requireDataStreamsReportIsVaid(bytes32 streamId, bytes memory verifiedPriceData) external pure {
        SettlementConfiguration.requireDataStreamsReportIsValid(streamId, verifiedPriceData);
    }

    function exposed_verifyOffchainPrice(
        uint128 marketId,
        uint128 settlementConfigurationId,
        bytes memory priceData,
        bool isBuyOrder
    )
        external
        returns (UD60x18)
    {
        SettlementConfiguration.Data storage self = SettlementConfiguration.load(marketId, settlementConfigurationId);

        return SettlementConfiguration.verifyOffchainPrice(self, priceData, isBuyOrder);
    }

    function exposed_verifyDataStreamsReport(
        SettlementConfiguration.DataStreamsStrategy memory dataStreamsStrategy,
        bytes memory signedReport
    )
        external
        returns (bytes memory)
    {
        return SettlementConfiguration.verifyDataStreamsReport(dataStreamsStrategy, signedReport);
    }
}
