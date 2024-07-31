// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

library Stake {
    /// @notice ERC7201 storage location.
    bytes32 internal constant STAKE_LOCATION =
        keccak256(abi.encode(uint256(keccak256("fi.zaros.market-making.Stake")) - 1));

    struct Data {
        uint256 shares;
    }

    /// @notice Loads a {Stake} namespace.
    /// @param vaultId The vault identifier.
    /// @param account The staker address.
    function load(uint256 vaultId, address account) internal pure returns (Data storage stake) {
        bytes32 slot = keccak256(abi.encode(STAKE_LOCATION, vaultId, account));
        assembly {
            stake.slot := slot
        }
    }
}
