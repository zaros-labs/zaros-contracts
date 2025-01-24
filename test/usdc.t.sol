// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { LiquidationBranch } from "@zaros/perpetuals/branches/LiquidationBranch.sol";
import { MarketOrder } from "@zaros/perpetuals/leaves/MarketOrder.sol";
import { Position } from "@zaros/perpetuals/leaves/Position.sol";
import { Base_Test } from "test/Base.t.sol";
import { PerpMarket } from "@zaros/perpetuals/leaves/PerpMarket.sol";

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

import { LimitedMintingERC20 } from "testnet/LimitedMintingERC20.sol";

import { console } from "forge-std/console.sol";

import { UUPSUpgradeable } from "@openzeppelin/proxy/utils/UUPSUpgradeable.sol";

contract Usdc is Base_Test {
    function setUp() public override {
        uint256 mainnetFork = vm.createFork("https://arb-sepolia.g.alchemy.com/v2/ZE47XPcJHitGgQu_XQ_xcu09lo5sklyj");
        vm.selectFork(mainnetFork);
    }

    function test_usdc() external {

        address deployer;
        uint256 privateKey;

        privateKey = vm.envOr("PRIVATE_KEY", uint256(1));
        deployer = vm.rememberKey(privateKey);
        changePrank({ msgSender: deployer });


        LimitedMintingERC20 usdc = LimitedMintingERC20(address(0x95011b96c11A4cc96CD8351165645E00F68632a3));

        address usdcNewImplementation = address(new LimitedMintingERC20());

        UUPSUpgradeable(address(usdc)).upgradeToAndCall(
            usdcNewImplementation, bytes("")
        );

        (uint256 userLastMintedTimestamp, uint256 userBalanceOf, uint128 tradingAccountId, int256 marginBalanceX18, bool userIsEnableToMint) =
            usdc.getUserRawData(address(0x7829267A8727E0b5C2Bb896357e37eBa43680483), 0);

        console.log("userLastMintedTimestamp: ", userLastMintedTimestamp);
        console.log("userBalanceOf: ", userBalanceOf);
        console.log("tradingAccountId: ", tradingAccountId);
        console.log("marginBalanceX18: ", marginBalanceX18);
        console.log("userIsEnableToMint: ", userIsEnableToMint);
    }

}
