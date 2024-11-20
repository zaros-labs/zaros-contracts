// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// TODO: Make it a custom trigger, streams compatible, automation keeper
// TODO: deploy one per engine, listening to all of the engine's market ids.
contract MarketCollateralSettlementKeeper {
    function checkUpkeep() external returns (bool, bytes memory) {
        // uint128[] memory marketsIdsToSettle;
        // return (true, abi.encode(marketsIdsToSettle));
    }
}
