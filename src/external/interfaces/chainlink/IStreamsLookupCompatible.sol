// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

struct BasicReport {
    // v0.3 Basic
    bytes32 feedId; // The feed ID the report has data for
    uint32 lowerTimestamp; // Lower timestamp for validity of report
    uint32 observationsTimestamp; // The time the median value was observed on
    uint192 nativeFee; // Base ETH/WETH fee to verify report
    uint192 linkFee; // Base LINK fee to verify report
    uint64 upperTimestamp; // Upper timestamp for validity of report
    int192 benchmark; // The median value agreed in an OCR round
}

struct Quote {
    address quoteAddress;
}

interface IStreamsLookupCompatible {
    error StreamsLookup(string feedParamKey, string[] feeds, string timeParamKey, uint256 time, bytes extraData);

    /**
     * @notice any contract which wants to utilize StreamsLookup feature needs to
     * implement this interface as well as the automation compatible interface.
     * @param values an array of bytes returned from data streams endpoint.
     * @param extraData context data from streams lookup process.
     * @return upkeepNeeded boolean to indicate whether the keeper should call performUpkeep or not.
     * @return performData bytes that the keeper should call performUpkeep with, if
     * upkeep is needed. If you would like to encode data to decode later, try `abi.encode`.
     */
    function checkCallback(
        bytes[] memory values,
        bytes memory extraData
    )
        external
        view
        returns (bool upkeepNeeded, bytes memory performData);
}
