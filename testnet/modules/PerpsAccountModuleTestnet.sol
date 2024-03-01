// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { IAccountNFT } from "@zaros/account-nft/interfaces/IAccountNFT.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { IPerpsAccountModule } from "@zaros/markets/perps/interfaces/IPerpsAccountModule.sol";
import { PerpsAccountModule } from "@zaros/markets/perps/modules/PerpsAccountModule.sol";
import { PerpsAccount } from "@zaros/markets/perps/storage/PerpsAccount.sol";
import { GlobalConfiguration } from "@zaros/markets/perps/storage/GlobalConfiguration.sol";
import { PerpMarket } from "@zaros/markets/perps/storage/PerpMarket.sol";
import { Position } from "@zaros/markets/perps/storage/Position.sol";
import { MarginCollateralConfiguration } from "@zaros/markets/perps/storage/MarginCollateralConfiguration.sol";

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

interface AccessKeyManager {
    function isUserActive(address user) external view returns (bool);
}

/// @notice See {IPerpsAccountModule}.
contract PerpsAccountModuleTestnet is PerpsAccountModule, Initializable, OwnableUpgradeable {
    AccessKeyManager internal accessKeyManager;
    mapping(address user => bool accountCreated) internal isAccountCreated;

    error UserWithoutAccess();
    error UserAlreadyHasAccount();

    constructor() {
        _disableInitializers();
    }

    function initialize(address _accessKeyManager) external initializer
    {
        accessKeyManager = AccessKeyManager(_accessKeyManager);
    }

    function getAccessKeyManager() external view returns (address) {
        return address(accessKeyManager);
    }

    function isUserAccountCreated(address user) external view returns (bool) {
        return isAccountCreated[user];
    }

    function createPerpsAccount() public override returns (uint128) {}

    function createPerpsAccount(bytes memory referral, bool isCustom) public returns (uint128) {

        bool userHasAccount = isAccountCreated[msg.sender];
        if (userHasAccount) {
            revert UserAlreadyHasAccount();
        }

        uint128 perpsAccountId = super.createPerpsAccount();
        isAccountCreated[msg.sender] = true;

        return perpsAccountId;
    }

}
