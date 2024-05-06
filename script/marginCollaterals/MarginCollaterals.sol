// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Margin Collaterals
import { Usdc } from "script/marginCollaterals/Usdc.sol";
import { Usdz } from "script/marginCollaterals/Usdz.sol";
import { WeEth } from "script/marginCollaterals/WeEth.sol";
import { WstEth } from "script/marginCollaterals/WstEth.sol";

abstract contract MarginCollaterals is Usdc, Usdz, WeEth, WstEth { }
