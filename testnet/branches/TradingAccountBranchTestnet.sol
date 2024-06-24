// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;

// Zaros dependencies
import { TradingAccountBranch } from "@zaros/perpetuals/branches/TradingAccountBranch.sol";
import { TradingAccount } from "@zaros/perpetuals/leaves/TradingAccount.sol";
import { CustomReferralConfigurationTestnet } from "../leaves/CustomReferralConfigurationTestnet.sol";
import { ReferralTestnet } from "../leaves/ReferralTestnet.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";
import { Initializable } from "@openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

contract TradingAccountBranchTestnet is TradingAccountBranch, Initializable, OwnableUpgradeable {
    using TradingAccount for TradingAccount.Data;
    using ReferralTestnet for ReferralTestnet.Data;

    mapping(address user => bool accountCreated) internal isAccountCreated;

    error UserWithoutAccess();
    error UserAlreadyHasAccount();
    error InvalidReferralCode();
    error FaucetAlreadyDeposited();

    event LogReferralSet(
        address indexed user, address indexed referrer, bytes referralCode, bool isCustomReferralCode
    );

    constructor() {
        _disableInitializers();
    }

    function isUserAccountCreated(address user) external view returns (bool) {
        return isAccountCreated[user];
    }

    function getUserReferralData(address user) external pure returns (bytes memory, bool) {
        ReferralTestnet.Data memory referral = ReferralTestnet.load(user);

        return (referral.referralCode, referral.isCustomReferralCode);
    }

    function createTradingAccount() public override returns (uint128) { }

    function createTradingAccount(bytes memory referralCode, bool isCustomReferralCode) public returns (uint128) {
        bool userHasAccount = isAccountCreated[msg.sender];
        if (userHasAccount) {
            revert UserAlreadyHasAccount();
        }

        uint128 tradingAccountId = super.createTradingAccount();
        isAccountCreated[msg.sender] = true;

        ReferralTestnet.Data storage referral = ReferralTestnet.load(msg.sender);

        if (referralCode.length != 0 && referral.referralCode.length == 0) {
            if (isCustomReferralCode) {
                CustomReferralConfigurationTestnet.Data storage customReferral =
                    CustomReferralConfigurationTestnet.load(string(referralCode));
                if (customReferral.referrer == address(0)) {
                    revert InvalidReferralCode();
                }
                referral.referralCode = referralCode;
                referral.isCustomReferralCode = true;
            } else {
                address referrer = abi.decode(referralCode, (address));

                if (referrer == msg.sender) {
                    revert InvalidReferralCode();
                }

                referral.referralCode = referralCode;
                referral.isCustomReferralCode = false;
            }

            emit LogReferralSet(msg.sender, referral.getReferrerAddress(), referralCode, isCustomReferralCode);
        }

        return tradingAccountId;
    }

    function createTradingAccountAndMulticall(bytes[] calldata data)
        external
        payable
        override
        returns (bytes[] memory results)
    { }

    function createTradingAccountAndMulticall(
        bytes[] calldata data,
        bytes memory referralCode,
        bool isCustomReferralCode
    )
        external
        payable
        returns (bytes[] memory results)
    {
        uint128 tradingAccountId = createTradingAccount(referralCode, isCustomReferralCode);

        results = new bytes[](data.length);
        for (uint256 i; i < data.length; i++) {
            bytes memory dataWithAccountId = abi.encodePacked(data[i][0:4], abi.encode(tradingAccountId), data[i][4:]);
            (bool success, bytes memory result) = address(this).delegatecall(dataWithAccountId);

            if (!success) {
                uint256 len = result.length;
                assembly {
                    revert(add(result, 0x20), len)
                }
            }

            results[i] = result;
        }
    }

    function depositMargin(
        uint128 tradingAccountId,
        address collateralType,
        uint256 amount
    )
        public
        virtual
        override
    {
        super.depositMargin(tradingAccountId, collateralType, amount);

        TradingAccount.Data storage tradingAccount = TradingAccount.loadExisting(tradingAccountId);
        UD60x18 marginCollateralBalance = tradingAccount.getMarginCollateralBalance(collateralType);

        if (marginCollateralBalance > ud60x18(100_000e18)) {
            revert FaucetAlreadyDeposited();
        }
    }
}
