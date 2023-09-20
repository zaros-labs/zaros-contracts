// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

/// @notice Chainlink Data Streams Report data structure.
/// @param feedId The feed ID the report has data for
/// @param median The median value agreed in an OCR round
/// @param observationsTimestamp The time the median value was observed on
/// @param bid The best bid value agreed in an OCR round
/// @param ask The best ask value agreed in an OCR round
/// @param blockNumberUpperBound The upper bound of the block range the median value was observed within
/// @param upperBlockhash The blockhash for the upper bound of block range (ensures correct blockchain)
/// @param blockNumberLowerBound The lower bound of the block range the median value was observed within
/// @param currentBlockTimestamp The timestamp of the current (upperbound) block number
struct Report {
    bytes32 feedId;
    uint32 observationsTimestamp;
    int192 median;
    int192 bid;
    int192 ask;
    uint64 blockNumberUpperBound;
    bytes32 upperBlockhash;
    uint64 blockNumberLowerBound;
    uint64 currentBlockTimestamp;
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
