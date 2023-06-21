// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

// Zaros dependencies
import { AccountRBAC } from "../storage/AccountRBAC.sol";
import { Collateral } from "../storage/Collateral.sol";
import { Vault } from "../storage/Vault.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

/**
 * @title Object for tracking accounts with access control and collateral tracking.
 */
library Account {
    using AccountRBAC for AccountRBAC.Data;
    using Collateral for Collateral.Data;
    using EnumerableSet for EnumerableSet.UintSet;
    using Vault for Vault.Data;
    using SafeCast for uint256;

    /// @dev Constant base domain used to access a given account's storage slot
    string internal constant ACCOUNT_DOMAIN = "fi.zaros.core.Account";

    /**
     * @dev Thrown when the given target address does not have the given permission with the given account.
     */
    error Zaros_Account_PermissionDenied(uint128 accountId, bytes32 permission, address target);

    /**
     * @dev Thrown when an account cannot be found.
     */
    error Zaros_Account_AccountNotFound(uint128 accountId);

    /**
     * @dev Thrown when an account does not have sufficient collateral for a particular operation in the system.
     */
    error Zaros_Account_InsufficientAccountCollateral(uint256 requestedAmount);

    /**
     * @dev Thrown when the requested operation requires an activity timeout before the
     */
    error Zaros_Account_AccountActivityTimeoutPending(uint128 accountId, uint256 currentTime, uint256 requiredTime);

    struct Data {
        /**
         * @dev Numeric identifier for the account. Must be unique.
         * @dev There cannot be an account with id zero (See ERC721._mint()).
         */
        uint128 id;
        /**
         * @dev Role based access control data for the account.
         */
        AccountRBAC.Data rbac;
        uint64 lastInteraction;
        uint64 __slotAvailableForFutureUse;
        uint128 __slot2AvailableForFutureUse;
        /**
         * @dev Address set of collaterals that are being used in the system by this account.
         */
        mapping(address => Collateral.Data) collaterals;
    }

    /**
     * @dev Returns the account stored at the specified account id.
     */
    function load(uint128 id) internal pure returns (Data storage account) {
        bytes32 s = keccak256(abi.encode(ACCOUNT_DOMAIN, id));
        assembly {
            account.slot := s
        }
    }

    /**
     * @dev Creates an account for the given id, and associates it to the given owner.
     *
     * Note: Will not fail if the account already exists, and if so, will overwrite the existing owner. Whatever calls
     * this internal function must first check that the account doesn't exist before re-creating it.
     */
    function create(uint128 id, address owner) internal returns (Data storage account) {
        account = load(id);

        account.id = id;
        account.rbac.owner = owner;
    }

    /**
     * @dev Reverts if the account does not exist with appropriate error. Otherwise, returns the account.
     */
    function exists(uint128 id) internal view returns (Data storage account) {
        Data storage a = load(id);
        if (a.rbac.owner == address(0)) {
            revert Zaros_Account_AccountNotFound(id);
        }

        return a;
    }

    /**
     * @dev Given a collateral type, returns information about the total collateral assigned and deposited by
     * the account
     */
    function getCollateralTotals(
        Data storage self,
        address collateralType
    )
        internal
        view
        returns (UD60x18 totalDeposited, UD60x18 totalAssigned)
    {
        totalAssigned = getAssignedCollateral(self, collateralType);
        totalDeposited = totalAssigned.add(ud60x18(self.collaterals[collateralType].amountAvailableForDelegation));

        return (totalDeposited, totalAssigned);
    }

    /**
     * @dev Returns the total amount of collateral that has been delegated, for the given
     * collateral type.
     */
    function getAssignedCollateral(Data storage self, address collateralType) internal view returns (UD60x18) {
        Vault.Data storage vault = Vault.load(collateralType);
        UD60x18 assignedCollateral = vault.currentAccountCollateral(self.id);

        return assignedCollateral;
    }

    function recordInteraction(Data storage self) internal {
        // solhint-disable-next-line numcast/safe-cast
        self.lastInteraction = uint64(block.timestamp);
    }

    /**
     * @dev Loads the Account object for the specified accountId,
     * and validates that sender has the specified permission. It also resets
     * the interaction timeout. These
     * are different actions but they are merged in a single function
     * because loading an account and checking for a permission is a very
     * common use case in other parts of the code.
     */
    function loadAccountAndValidatePermission(
        uint128 accountId,
        bytes32 permission
    )
        internal
        returns (Data storage account)
    {
        account = Account.load(accountId);

        if (!account.rbac.authorized(permission, msg.sender)) {
            revert Zaros_Account_PermissionDenied(accountId, permission, msg.sender);
        }

        recordInteraction(account);
    }

    /**
     * @dev Loads the Account object for the specified accountId,
     * and validates that sender has the specified permission. It also resets
     * the interaction timeout. These
     * are different actions but they are merged in a single function
     * because loading an account and checking for a permission is a very
     * common use case in other parts of the code.
     */
    function loadAccountAndValidatePermissionAndTimeout(
        uint128 accountId,
        bytes32 permission,
        uint256 timeout
    )
        internal
        view
        returns (Data storage account)
    {
        account = Account.load(accountId);

        if (!account.rbac.authorized(permission, msg.sender)) {
            revert Zaros_Account_PermissionDenied(accountId, permission, msg.sender);
        }

        uint256 endWaitingPeriod = account.lastInteraction + timeout;
        if (block.timestamp < endWaitingPeriod) {
            revert Zaros_Account_AccountActivityTimeoutPending(accountId, block.timestamp, endWaitingPeriod);
        }
    }

    /**
     * @dev Ensure that the account has the required amount of collateral funds remaining
     */
    function requireSufficientCollateral(uint128 accountId, address collateralType, UD60x18 wad) internal view {
        if (ud60x18(Account.load(accountId).collaterals[collateralType].amountAvailableForDelegation).lt(wad)) {
            revert Zaros_Account_InsufficientAccountCollateral(wad.intoUint256());
        }
    }
}
