// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { ITradingAccountBranch } from "@zaros/perpetuals/interfaces/ITradingAccountBranch.sol";
import { ReferralTestnet } from "../leaves/ReferralTestnet.sol";

interface ITradingAccountBranchTestnet is ITradingAccountBranch {
    event LogReferralSet(
        address indexed user, address indexed referrer, bytes referralCode, bool isCustomReferralCode
    );

    function getAccessKeyManager() external view returns (address);

    function isUserAccountCreated(address user) external view returns (bool);

    function getPointsOfUser(address user) external view returns (uint256 amount);

    function getUserReferralData(address user) external pure returns (ReferralTestnet.Data memory);

    function getCustomReferralCodeReferee(string memory customReferralCode) external view returns (address);

    function createTradingAccount(bytes memory referralCode, bool isCustomReferralCode) external returns (uint128);

    function createTradingAccountAndMulticall(
        bytes[] calldata data,
        bytes memory referralCode,
        bool isCustomReferralCode
    )
        external
        payable
        returns (bytes[] memory results);
}
