// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { AddressError } from "@zaros/utils/Errors.sol";
import { IStrategy } from "./interfaces/IStrategy.sol";

// Open Zeppelin dependencies
import { ERC4626, ERC20, IERC20 } from "@openzeppelin/token/ERC20/extensions/ERC4626.sol";
import { ReentrancyGuard } from "@openzeppelin/security/ReentrancyGuard.sol";

// contract BalancerUSDCStrategy is IStrategy, ERC4626, ReentrancyGuard {
//     address private _zaros;
//     uint256 private _totalUsdcInvested;

//     modifier onlyZaros() {
//         if (msg.sender != _zaros) {
//             revert AddressError.Zaros_Unauthorized(msg.sender);
//         }
//         _;
//     }

//     constructor(
//         address zaros,
//         IERC20 usdc
//     )
//         ERC4626(usdc)
//         ERC20("Zaros zrsUSD/USDC Balancer Strategy", "zrsUSD/USDC-BAL")
//     {
//         _zaros = zaros;
//     }

//     function deposit(uint256 assets, address receiver) public override nonReentrant onlyZaros returns (uint256) {
//         return super.deposit(assets, receiver);
//     }

//     function mint(uint256 shares, address receiver) public override nonReentrant onlyZaros returns (uint256) {
//         return super.mint(shares, receiver);
//     }

//     function withdraw(
//         uint256 assets,
//         address receiver,
//         address owner
//     )
//         public
//         override
//         nonReentrant
//         onlyZaros
//         returns (uint256)
//     {
//         return super.withdraw(assets, receiver, owner);
//     }
// }

contract BalancerUSDCStrategy { }
