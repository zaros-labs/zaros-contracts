// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

// Zaros dependencies
import { IAggregatorV3 } from "@zaros/external/chainlink/interfaces/IAggregatorV3.sol";
import { ChainlinkUtil } from "@zaros/external/chainlink/ChainlinkUtil.sol";
import { IPerpsEngine } from "@zaros/perpetuals/PerpsEngine.sol";

/// @notice The interface for the price adapter.
interface IPriceAdapter {
    /// @notice Gets the price of the token.
    /// @return price The price of the token.
    function getPrice() external view returns (UD60x18 price);
}

contract PriceAdapter is IPriceAdapter {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice The Zaros Perpetuals Engine.
    address perpsEngine;

    /// @notice The Chainlink Price Feed address.
    address public immutable priceFeed;

    /// @notice The Chainlink ETH/USD Price Feed address.
    address immutable ethUsdPriceFeed;

    /// @notice The number of seconds between price feed updates.
    uint32 immutable priceFeedHeartbeatSeconds;

    /// @notice The number of seconds between ETH/USD price feed updates.
    uint32 immutable ethUsdPriceFeedHeartbeatSeconds;

    /// @notice A flag indicating if the price adapter is to use the custom version.
    bool public immutable useCustomPriceAdapter;

    /*//////////////////////////////////////////////////////////////////////////
                                     STRUCTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice The constructor parameters.
    /// @param _perpsEngine The Zaros Perpetuals Engine.
    /// @param _priceFeed The Chainlink Price Feed address.
    /// @param _ethUsdPriceFeed The Chainlink ETH/USD Price Feed address.
    /// @param _priceFeedHeartbeatSeconds The number of seconds between price feed updates.
    /// @param _ethUsdPriceFeedHeartbeatSeconds The number of seconds between ETH/USD price feed updates.
    /// @param _useCustomPriceAdapter A flag indicating if the price adapter is to use the custom version.
    struct ConstructorParams {
        address perpsEngine;
        address priceFeed;
        address ethUsdPriceFeed;
        uint32 priceFeedHeartbeatSeconds;
        uint32 ethUsdPriceFeedHeartbeatSeconds;
        bool useCustomPriceAdapter;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     INITIALIZE
    //////////////////////////////////////////////////////////////////////////*/

    constructor(ConstructorParams memory params) {
        perpsEngine = params.perpsEngine;
        priceFeed = params.priceFeed;
        ethUsdPriceFeed = params.ethUsdPriceFeed;
        priceFeedHeartbeatSeconds = params.priceFeedHeartbeatSeconds;
        ethUsdPriceFeedHeartbeatSeconds = params.ethUsdPriceFeedHeartbeatSeconds;
        useCustomPriceAdapter = params.useCustomPriceAdapter;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Gets the price of the token.
    /// @return price The price of the token.
    function getPrice() external view returns (UD60x18 price) {
        address sequencerUptimeFeed = IPerpsEngine(perpsEngine).getSequencerUptimeFeedByChainId(block.chainid);

        if (useCustomPriceAdapter) {
            UD60x18 quantityTokenInEth = ChainlinkUtil.getPrice(
                ChainlinkUtil.GetPriceParams({
                    priceFeed: IAggregatorV3(priceFeed),
                    priceFeedHeartbeatSeconds: priceFeedHeartbeatSeconds,
                    sequencerUptimeFeed: IAggregatorV3(sequencerUptimeFeed)
                })
            );

            UD60x18 ethUsdPrice = ChainlinkUtil.getPrice(
                ChainlinkUtil.GetPriceParams({
                    priceFeed: IAggregatorV3(ethUsdPriceFeed),
                    priceFeedHeartbeatSeconds: ethUsdPriceFeedHeartbeatSeconds,
                    sequencerUptimeFeed: IAggregatorV3(sequencerUptimeFeed)
                })
            );

            price = quantityTokenInEth.mul(ethUsdPrice);
        } else {
            price = ChainlinkUtil.getPrice(
                ChainlinkUtil.GetPriceParams({
                    priceFeed: IAggregatorV3(priceFeed),
                    priceFeedHeartbeatSeconds: priceFeedHeartbeatSeconds,
                    sequencerUptimeFeed: IAggregatorV3(sequencerUptimeFeed)
                })
            );
        }
    }
}
