//SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

// Zaros dependencies
import { IAccountNFT } from "@zaros/account-nft/interfaces/IAccountNFT.sol";

library SystemAccountConfiguration {
    bytes32 internal constant SYSTEM_ACCOUNT_CONFIGURATION_SLOT =
        keccak256(abi.encode("fi.liquidityEngine.core.SystemAccountConfiguration"));

    struct Data {
        uint96 nextAccountId;
        address accountToken;
    }

    function load() internal pure returns (Data storage systemAccountConfiguration) {
        bytes32 s = SYSTEM_ACCOUNT_CONFIGURATION_SLOT;
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
