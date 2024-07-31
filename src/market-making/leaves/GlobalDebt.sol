// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Distribution } from "./Distribution.sol";

library GlobalDebt {
    bytes32 internal constant GLOBAL_DEBT_LOCATION =
        keccak256(abi.encode(uint256(keccak256("fi.zaros.market-making.GlobalDebt")) - 1));

    struct Data {
        int256 totalUnsettledDebt;
        int256 totalSettledDebt;
        uint256 totalMarketsCreditWeight;
        Distribution.Data vaultsDebtDistribution;
    }

    /// @notice Loads the {GlobalDebt} namespace.
    function load() internal pure returns (Data storage globalDebt) {
        bytes32 slot = keccak256(abi.encode(GLOBAL_DEBT_LOCATION));
        assembly {
            globalDebt.slot := slot
        }
    }
}
