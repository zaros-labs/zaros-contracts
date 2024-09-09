// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { BaseScript } from "../Base.s.sol";
import { IPerpsEngineTestnet } from "testnet/PerpsEngineTestnet.sol";

// Forge dependencies
import { console } from "forge-std/console.sol";

struct TradingAccountData {
    uint128 id;
    address sender;
    bytes referralCode;
    bool isCustomReferralCode;
}

struct ListOfTradingAccounts {
    TradingAccountData[] data;
}

/// @dev This script creates a list of trading accounts.
contract CreateListOfTradingAccounts is BaseScript {
    IPerpsEngineTestnet internal perpsEngine;

    function run() public broadcaster {
        perpsEngine = IPerpsEngineTestnet(vm.envAddress("PERPS_ENGINE"));

        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/script/testnet/listOfTradingAccounts.json");
        string memory json = vm.readFile(path);
        bytes memory data = vm.parseJson(json);

        ListOfTradingAccounts memory listOfTradingAccounts = abi.decode(data, (ListOfTradingAccounts));

        for (uint256 i; i < listOfTradingAccounts.data.length; i++) {
            perpsEngine.createTradingAccountWithSender(
                listOfTradingAccounts.data[i].sender,
                listOfTradingAccounts.data[i].referralCode,
                listOfTradingAccounts.data[i].isCustomReferralCode
            );
        }

        console.log("List of trading accounts created");
    }
}
