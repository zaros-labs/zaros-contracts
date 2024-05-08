// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { TradingAccountBranch } from "@zaros/perpetuals/branches/TradingAccountBranch.sol";
import { ReferralTestnet } from "../leaves/ReferralTestnet.sol";

abstract contract ITradingAccountBranchTestnet is TradingAccountBranch {
    event LogReferralSet(
        address indexed user, address indexed referrer, bytes referralCode, bool isCustomReferralCode
    );

    function getAccessKeyManager() external view virtual returns (address);

    function isUserAccountCreated(address user) external view virtual returns (bool);

    function getPointsOfUser(address user) external view virtual returns (uint256 amount);

    function getUserReferralData(address user) external pure virtual returns (ReferralTestnet.Data memory);

    function getCustomReferralCodeReferee(string memory customReferralCode) external view virtual returns (address);

    function createTradingAccount(
        bytes memory referralCode,
        bool isCustomReferralCode
    )
        external
        virtual
        returns (uint128);

    function createTradingAccountAndMulticall(
        bytes[] calldata data,
        bytes memory referralCode,
        bool isCustomReferralCode
    )
        external
        payable
        virtual
        returns (bytes[] memory results);
}
