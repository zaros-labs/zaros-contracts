// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

contract MockPriceFeed {
    uint8 private _decimals;
    int256 private _price;

    constructor(uint8 decimals_, int256 price_) {
        _decimals = decimals_;
        _price = price_;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (0, _price, 0, 0, 0);
    }
}
