// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

interface IFeeManager {
    struct PaymentAsset {
        address assetAddress;
        uint256 amount;
    }

    function getFeeAndReward(
        address subscriber,
        bytes memory report,
        address quoteAddress
    )
        external
        returns (PaymentAsset memory, PaymentAsset memory, uint256);

    function i_linkAddress() external view returns (address);

    function i_nativeAddress() external view returns (address);

    function i_rewardManager() external view returns (address);
}
