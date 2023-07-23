//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// Zaros dependencies
import { IAccountNFT } from "@zaros/account-nft/interfaces/IAccountNFT.sol";

library SystemAccountConfiguration {
    bytes32 private constant _SYSTEM_ACCOUNT_CONFIGURATION_SLOT =
        keccak256(abi.encode("fi.zaros.core.SystemAccountConfiguration"));

    struct Data {
        uint96 nextAccountId;
        address accountToken;
    }

    function load() internal pure returns (Data storage systemAccountConfiguration) {
        bytes32 s = _SYSTEM_ACCOUNT_CONFIGURATION_SLOT;
        assembly {
            systemAccountConfiguration.slot := s
        }
    }

    function onCreateAccount() internal returns (uint128 accountId, IAccountNFT accountTokenModule) {
        Data storage self = load();
        accountId = ++self.nextAccountId;
        accountTokenModule = IAccountNFT(self.accountToken);
    }
}
