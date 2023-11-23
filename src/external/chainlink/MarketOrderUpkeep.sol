// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { IFeeManager } from "@zaros/external/chainlink/interfaces/IFeeManager.sol";
import { ILogAutomation, Log as AutomationLog } from "@zaros/external/chainlink/interfaces/ILogAutomation.sol";
import { IStreamsLookupCompatible } from "@zaros/external/chainlink/interfaces/IStreamsLookupCompatible.sol";
import { IVerifierProxy } from "@zaros/external/chainlink/interfaces/IVerifierProxy.sol";
import { Constants } from "@zaros/utils/Constants.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { Order } from "@zaros/markets/perps/storage/Order.sol";

// Open Zeppelin dependencies
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

contract MarketOrderUpkeep is ILogAutomation, IStreamsLookupCompatible {
    using SafeCast for uint256;

    modifier onlyForwarder() {
        address forwarder;
        if (msg.sender != forwarder) {
            revert Errors.OnlyForwarder(msg.sender, forwarder);
        }
        _;
    }

    function checkLog(
        AutomationLog calldata log,
        bytes calldata checkData
    )
        external
        pure
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        (uint256 accountId, uint128 marketId) = (uint256(log.topics[2]), uint256(log.topics[3]).toUint128());
        // bytes32 streamId = PerpsMarket.load(marketId).streamId;
        (Order.Data memory order) = abi.decode(log.data, (Order.Data));

        // TODO: we should probably have orderType as an indexed parameter?
        if (order.payload.orderType != Order.OrderType.MARKET) {
            return (false, bytes(""));
        }

        // TODO: add proper order.validate() check
        string[] memory feeds = new string[](1);
        if (marketId == 1) {
            feeds[0] = Constants.DATA_STREAMS_ETH_USD_STREAM_ID;
        } else if (marketId == 2) {
            feeds[0] = Constants.DATA_STREAMS_LINK_USD_STREAM_ID;
        } else {
            revert();
        }

        bytes memory extraData = abi.encode(accountId, marketId, order.id);

        revert StreamsLookup(
            Constants.DATA_STREAMS_FEED_LABEL,
            feeds,
            Constants.DATA_STREAMS_QUERY_LABEL,
            order.settlementTimestamp,
            extraData
        );
    }

    function checkCallback(
        bytes[] memory values,
        bytes memory extraData
    )
        external
        pure
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        return (true, abi.encode(values, extraData));
    }

    function performUpkeep(bytes calldata performData) external { }
}
