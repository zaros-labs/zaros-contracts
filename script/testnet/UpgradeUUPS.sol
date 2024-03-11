// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { MarketOrderUpkeep } from "@zaros/external/chainlink/upkeeps/market-order/MarketOrderUpkeep.sol";
import { LimitedMintingERC20 } from "@zaros/testnet/LimitedMintingERC20.sol";
import { BaseScript } from "../Base.s.sol";

// import { MockSettlementModule } from "test/mocks/MockSettlementModule.sol";

// Open Zeppelin dependencies
import { ERC1967Proxy } from "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import { UUPSUpgradeable } from "@openzeppelin/proxy/utils/UUPSUpgradeable.sol";

// Forge dependencies
import { console } from "forge-std/console.sol";

contract UpdateModules is BaseScript {
    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/
    LimitedMintingERC20 internal usdc;
    LimitedMintingERC20 internal usdz;

    function run() public broadcaster {
        usdc = LimitedMintingERC20(vm.envAddress("USDC"));

        address newImplementation = address(new LimitedMintingERC20());

        UUPSUpgradeable(address(usdc)).upgradeToAndCall(newImplementation, bytes(""));
    }
}
