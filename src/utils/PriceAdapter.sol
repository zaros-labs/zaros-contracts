// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

// Zaros dependencies
import { IAggregatorV3 } from "@zaros/external/chainlink/interfaces/IAggregatorV3.sol";
import { ChainlinkUtil } from "@zaros/external/chainlink/ChainlinkUtil.sol";

// Open Zeppelin dependencies
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @notice The interface for the price adapter.
interface IPriceAdapter {
    /// @notice Gets the price of the token.
    /// @return priceUsdX18 The USD quote of the token.
    function getPrice() external view returns (UD60x18 priceUsdX18);
}

contract PriceAdapter is IPriceAdapter, OwnableUpgradeable, UUPSUpgradeable {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice The Chainlink Price Feed address.
    address public priceFeed;

    /// @notice The Chainlink ETH/USD Price Feed address.
    address public ethUsdPriceFeed;

    /// @notice The Sequencer Uptime Feed address.
    address public sequencerUptimeFeed;

    /// @notice The number of seconds between price feed updates.
    uint32 public priceFeedHeartbeatSeconds;

    /// @notice The number of seconds between ETH/USD price feed updates.
    uint32 public ethUsdPriceFeedHeartbeatSeconds;

    /// @notice A flag indicating if the price adapter is to use the custom version.
    bool public useEthPriceFeed;

    /*//////////////////////////////////////////////////////////////////////////
                                     STRUCTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice The constructor parameters.
    /// @param owner The owner of the contract.
    /// @param _priceFeed The Chainlink Price Feed address.
    /// @param _ethUsdPriceFeed The Chainlink ETH/USD Price Feed address.
    /// @param _sequencerUptimeFeed The Sequencer Uptime Feed address.
    /// @param _priceFeedHeartbeatSeconds The number of seconds between price feed updates.
    /// @param _ethUsdPriceFeedHeartbeatSeconds The number of seconds between ETH/USD price feed updates.
    /// @param _useEthPriceFeed A flag indicating if the price adapter is to use the custom version.
    struct ConstructorParams {
        address owner;
        address priceFeed;
        address ethUsdPriceFeed;
        address sequencerUptimeFeed;
        uint32 priceFeedHeartbeatSeconds;
        uint32 ethUsdPriceFeedHeartbeatSeconds;
        bool useEthPriceFeed;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     INITIALIZE
    //////////////////////////////////////////////////////////////////////////*/

    function initialize(ConstructorParams memory params) external initializer {
        __Ownable_init(params.owner);

        priceFeed = params.priceFeed;
        ethUsdPriceFeed = params.ethUsdPriceFeed;
        sequencerUptimeFeed = params.sequencerUptimeFeed;
        priceFeedHeartbeatSeconds = params.priceFeedHeartbeatSeconds;
        ethUsdPriceFeedHeartbeatSeconds = params.ethUsdPriceFeedHeartbeatSeconds;
        useEthPriceFeed = params.useEthPriceFeed;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Gets the price of the token.
    /// @return priceUsdX18 The USD quote of the token.
    function getPrice() external view returns (UD60x18 priceUsdX18) {
        if (useEthPriceFeed) {
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

            priceUsdX18 = quantityTokenInEth.mul(ethUsdPrice);
        } else {
            priceUsdX18 = ChainlinkUtil.getPrice(
                ChainlinkUtil.GetPriceParams({
                    priceFeed: IAggregatorV3(priceFeed),
                    priceFeedHeartbeatSeconds: priceFeedHeartbeatSeconds,
                    sequencerUptimeFeed: IAggregatorV3(sequencerUptimeFeed)
                })
            );
        }
    }

    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner { }
}
