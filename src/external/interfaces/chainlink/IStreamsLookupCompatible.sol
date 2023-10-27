// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

interface StreamsLookupCompatibleInterface {
    error StreamsLookup(string feedParamKey, string[] feeds, string timeParamKey, uint256 time, bytes extraData);

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

    struct PremiumReport {
        // v0.3 Premium
        bytes32 feedId; // The feed ID the report has data for
        uint32 validFromTimestamp; // Earliest timestamp for which price is applicable
        uint32 observationsTimestamp; // Latest timestamp for which price is applicable
        uint192 nativeFee; // Base cost to validate a transaction using the report, denominated in the chain’s native
            // token (WETH/ETH)
        uint192 linkFee; // Base cost to validate a transaction using the report, denominated in LINK
        uint32 expiresAt; // Latest timestamp where the report can be verified on-chain
        int192 price; // DON consensus median price, carried to 8 decimal places
        int192 bid; // Simulated price impact of a buy order up to the X% depth of liquidity utilisation
        int192 ask; // Simulated price impact of a sell order up to the X% depth of liquidity utilisation
    }

    /**
     * @notice any contract which wants to utilize FeedLookup feature needs to
     * implement this interface as well as the automation compatible interface.
     * @param values an array of bytes returned from Mercury endpoint.
     * @param extraData context data from feed lookup process.
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
