// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

// Zaros dependencies
import { BaseScript } from "../Base.s.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract DisperseTokens is BaseScript {
    function run() public broadcaster {
        IERC20 token = IERC20(address(uint160(0x0Aaed628D7D1B81D0a784dc50ce5969a8045705a)));

        token.transfer(address(uint160(0xe3B5076a39edd97481d078eff3c54D3c5da6b105)), 1e12);
        token.transfer(address(uint160(0x7FE07A4eAa179de0540e946BA2C5d7BAfd544563)), 1e12);
        token.transfer(address(uint160(0x0640cb62BaB2FdFE681237039Ef0b2a665eE352A)), 1e12);
        token.transfer(address(uint160(0xa6DbB7707Fbf744949E480827220F25Ac4257235)), 1e12);
        token.transfer(address(uint160(0x5A11a23Ba76534a269562ea86Aa4e254F46e4377)), 1e12);
        token.transfer(address(uint160(0x43741AA5AD8CCb3A0fb6EEC534c8380d7B3Ce741)), 1e12);
        token.transfer(address(uint160(0x111419b0173Ff13896b0771A0BE4c8cEC325485d)), 1e12);
        token.transfer(address(uint160(0x73436522e6193f2980b0a3210E22Abe5ed4F09b9)), 1e12);
        token.transfer(address(uint160(0xF61F795EfAE4aa813D4C2B1483E7674697b42B7C)), 1e12);
        token.transfer(address(uint160(0x7aF319D9138D30C191DEfDA0BDED91CA5D411c9C)), 1e12);
        token.transfer(address(uint160(0x7c7982945E70b4428a7Ffc400bb60713C4dA0Fa3)), 1e12);
    }
}
