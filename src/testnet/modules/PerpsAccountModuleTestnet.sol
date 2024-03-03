// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { AccessKeyManager } from "@zaros/testnet/access-key-manager/AccessKeyManager.sol";
import { PerpsAccountModule } from "@zaros/markets/perps/modules/PerpsAccountModule.sol";
import { PerpsAccount } from "@zaros/markets/perps/storage/PerpsAccount.sol";
import { Points } from "../storage/Points.sol";
import { CustomReferralConfigurationTestnet } from "../storage/CustomReferralConfigurationTestnet.sol";
import { ReferralTestnet } from "../storage/ReferralTestnet.sol";

// Open Zeppelin dependencies
import { EnumerableMap } from "@openzeppelin/utils/structs/EnumerableMap.sol";
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { IERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";
import { SafeERC20 } from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import { Initializable } from "@openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, ZERO as SD_ZERO } from "@prb-math/SD59x18.sol";

/// @notice See {IPerpsAccountModule}.
contract PerpsAccountModuleTestnet is PerpsAccountModule, Initializable, OwnableUpgradeable {
    using ReferralTestnet for ReferralTestnet.Data;

    AccessKeyManager internal accessKeyManager;
    mapping(address user => bool accountCreated) internal isAccountCreated;

    error UserWithoutAccess();
    error UserAlreadyHasAccount();
    error InvalidReferralCode();

    event LogReferralSet(
        address indexed user, address indexed referrer, bytes referralCode, bool isCustomReferralCode
    );

    constructor() {
        _disableInitializers();
    }

    function initialize(address _accessKeyManager) external initializer {
        accessKeyManager = AccessKeyManager(_accessKeyManager);
    }

    function getAccessKeyManager() external view returns (address) {
        return address(accessKeyManager);
    }

    function isUserAccountCreated(address user) external view returns (bool) {
        return isAccountCreated[user];
    }

    function getPointsOfUser(address user) external view returns (uint256 amount) {
        amount = Points.load(user).amount;
    }

    function getUserReferralData(address user) external pure returns (ReferralTestnet.Data memory) {
        ReferralTestnet.Data memory referral = ReferralTestnet.load(user);

        return referral;
    }

    function createPerpsAccount() public override returns (uint128) { }

    function createPerpsAccount(bytes memory referralCode, bool isCustomReferralCode) public returns (uint128) {
        bool userHasAccount = isAccountCreated[msg.sender];
        if (userHasAccount) {
            revert UserAlreadyHasAccount();
        }

        uint128 perpsAccountId = super.createPerpsAccount();
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
                referral.referralCode = referralCode;
                referral.isCustomReferralCode = false;
            }

            emit LogReferralSet(msg.sender, referral.getReferrerAddress(), referralCode, isCustomReferralCode);
        }

        return perpsAccountId;
    }

    function createPerpsAccountAndMulticall(bytes[] calldata data)
        external
        payable
        override
        returns (bytes[] memory results)
    { }

    function createPerpsAccountAndMulticall(
        bytes[] calldata data,
        bytes memory referralCode,
        bool isCustomReferralCode
    )
        external
        payable
        returns (bytes[] memory results)
    {
        uint128 accountId = createPerpsAccount(referralCode, isCustomReferralCode);

        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            bytes memory dataWithAccountId = abi.encodePacked(data[i][0:4], abi.encode(accountId), data[i][4:]);
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
}
