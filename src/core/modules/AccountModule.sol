// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { IAccountModule } from "../interfaces/IAccountModule.sol";
import { IAccountNFT } from "@zaros/account-nft/interfaces/IAccountNFT.sol";
import { Constants } from "@zaros/utils/Constants.sol";
import { Account } from "../storage/Account.sol";
import { FeatureFlag } from "../../utils/storage/FeatureFlag.sol";
import { SystemAccountConfiguration } from "../storage/SystemAccountConfiguration.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";

contract AccountModule is IAccountModule {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using Account for Account.Data;

    function getAccountTokenAddress() public view override returns (address) {
        return SystemAccountConfiguration.load().accountToken;
    }

    function getAccountOwner(uint128 accountId) public view returns (address) {
        return Account.load(accountId).owner;
    }

    function getAccountLastInteraction(uint128 accountId) external view returns (uint256 timestamp) {
        return Account.load(accountId).lastInteraction;
    }

    function createAccount() public override returns (uint128) {
        FeatureFlag.ensureAccessToFeature(Constants.CREATE_ACCOUNT_FEATURE_FLAG);
        (uint128 accountId, IAccountNFT accountTokenModule) = SystemAccountConfiguration.onCreateAccount();
        accountTokenModule.mint(msg.sender, accountId);

        Account.create(accountId, msg.sender);

        emit LogCreateAccount(accountId, msg.sender);
        return accountId;
    }

    function createAccountAndMulticall(bytes[] calldata data) external payable returns (bytes[] memory results) {
        uint128 accountId = createAccount();

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

    function notifyAccountTransfer(address to, uint128 accountId) external override {
        _onlyAccountToken();

        Account.Data storage account = Account.load(accountId);
        account.owner = to;
    }

    function _onlyAccountToken() internal view {
        if (msg.sender != address(getAccountTokenAddress())) {
            revert Zaros_AccountModule_OnlyAccountToken(msg.sender);
        }
    }

    function __AccountModule_init(address accountToken) internal {
        SystemAccountConfiguration.load().accountToken = accountToken;
    }
}
