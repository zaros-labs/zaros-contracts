// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Distribution } from "@zaros/market-making/leaves/Distribution.sol";
import { Vault } from "@zaros/market-making/leaves/Vault.sol";

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18 } from "@prb-math/SD59x18.sol";

contract DistributionHarness {
    function exposed_setActorShares(uint256 vaultId, bytes32 actorId, UD60x18 newActorShares) external {
        Vault.Data storage vault = Vault.load(vaultId);
        Distribution.Data storage self = vault.stakingFeeDistribution;
        Distribution.setActorShares(self, actorId, newActorShares);
    }
}
