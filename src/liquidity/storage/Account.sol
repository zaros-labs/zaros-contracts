// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { Collateral } from "../storage/Collateral.sol";
import { MarketManager } from "../storage/MarketManager.sol";
import { Vault } from "../storage/Vault.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

library Account {
    using Collateral for Collateral.Data;
    using EnumerableSet for EnumerableSet.UintSet;
    using Vault for Vault.Data;
    using SafeCast for uint256;

    /// @dev Constant base domain used to access a given account's storage slot
    string internal constant ACCOUNT_DOMAIN = "fi.zaros.core.Account";

    error Zaros_Account_PermissionDenied(uint128 accountId, address sender);

    error Zaros_Account_AccountNotFound(uint128 accountId);

    error Zaros_Account_InsufficientAccountCollateral(uint256 requestedAmount);

    error Zaros_Account_AccountActivityTimeoutPending(uint128 accountId, uint256 currentTime, uint256 requiredTime);

    struct Data {
        uint128 id;
        address owner;
        uint64 lastInteraction;
        mapping(address collateralType => Collateral.Data) collaterals;
    }

    function load(uint128 id) internal pure returns (Data storage account) {
        bytes32 s = keccak256(abi.encode(ACCOUNT_DOMAIN, id));
        assembly {
            account.slot := s
        }
    }

    function create(uint128 id, address owner) internal returns (Data storage account) {
        account = load(id);
        account.id = id;
        account.owner = owner;
    }

    function exists(uint128 id) internal view returns (Data storage account) {
        Data storage self = load(id);
        if (self.owner == address(0)) {
            revert Zaros_Account_AccountNotFound(id);
        }

        return self;
    }

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

    function getAssignedCollateral(Data storage self, address collateralType) internal view returns (UD60x18) {
        Vault.Data storage vault = MarketManager.load().vaults[collateralType];
        UD60x18 assignedCollateral = vault.currentAccountCollateral(self.id);

        return assignedCollateral;
    }

    function recordInteraction(Data storage self) internal {
        // solhint-disable-next-line numcast/safe-cast
        self.lastInteraction = uint64(block.timestamp);
    }

    function loadExistingAccountAndVerifySender(uint128 accountId) internal returns (Data storage account) {
        account = load(accountId);
        verifySender(account);

        recordInteraction(account);
    }

    function loadExistingAccountAndVerifySenderAndTimeout(
        uint128 accountId,
        uint256 timeout
    )
        internal
        view
        returns (Data storage account)
    {
        account = Account.load(accountId);
        verifySender(account);

        uint256 endWaitingPeriod = account.lastInteraction + timeout;
        if (block.timestamp < endWaitingPeriod) {
            revert Zaros_Account_AccountActivityTimeoutPending(accountId, block.timestamp, endWaitingPeriod);
        }
    }

    function verifySender(Data storage self) internal view {
        if (self.owner != msg.sender) {
            revert Zaros_Account_PermissionDenied(self.id, msg.sender);
        }
    }

    function requireSufficientCollateral(uint128 accountId, address collateralType, UD60x18 wad) internal view {
        if (ud60x18(Account.load(accountId).collaterals[collateralType].amountAvailableForDelegation).lt(wad)) {
            revert Zaros_Account_InsufficientAccountCollateral(wad.intoUint256());
        }
    }
}
