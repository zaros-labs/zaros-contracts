//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// Zaros dependencies
import { IAccountTokenModule } from "../interfaces/IAccountTokenModule.sol";

/**
 * @title System wide configuration for accounts.
 */
library SystemAccountConfiguration {
    bytes32 private constant _SYSTEM_ACCOUNT_CONFIGURATION_SLOT =
        keccak256(abi.encode("fi.zaros.core.SystemAccountConfiguration"));

    struct Data {
        /**
         * @dev Offset to use for auto-generated account IDs
         */
        uint96 nextAccountId;
        /**
         * @dev The address of the account token.
         */
        address accountToken;
    }

    /**
     * @dev Returns the configuration singleton.
     */
    function load() internal pure returns (Data storage systemAccountConfiguration) {
        bytes32 s = _SYSTEM_ACCOUNT_CONFIGURATION_SLOT;
        assembly {
            systemAccountConfiguration.slot := s
        }
    }

    function onCreateAccount() internal returns (uint128 accountId, IAccountTokenModule accountTokenModule) {
        Data storage self = load();
        accountId = self.nextAccountId++;
        accountTokenModule = IAccountTokenModule(self.accountToken);
    }
}
