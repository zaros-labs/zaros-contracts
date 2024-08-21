// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { PerpsEngineConfigurationBranch } from "@zaros/perpetuals/branches/PerpsEngineConfigurationBranch.sol";
import { CustomReferralConfigurationTestnet } from "../leaves/CustomReferralConfigurationTestnet.sol";
import { Points } from "../leaves/Points.sol";

import { LimitedMintingERC20 } from "testnet/LimitedMintingERC20.sol";

// Open Zeppelin dependencies
import { ERC1967Proxy } from "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import { UUPSUpgradeable } from "@openzeppelin/proxy/utils/UUPSUpgradeable.sol";

contract PerpsEngineConfigurationBranchTestnet is PerpsEngineConfigurationBranch {
    function setUserPoints(address user, uint256 value) external onlyOwner {
        Points.load(user).amount = value;
    }
}
