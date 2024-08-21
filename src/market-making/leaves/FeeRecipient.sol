// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

library FeeRecipient {
    /// @notice ERC7201 storage location.
    bytes32 internal constant FEE_RECIPIENT_LOCATION =
        keccak256(abi.encode(uint256(keccak256("fi.zaros.market-making.FeeRecipient")) - 1));

    struct Data {
        uint256 share;
    }

    /// @notice Loads a {FeeRecipient}.
    /// @param who The fee recipient address.
    /// @return feeRecipient The loaded fee recipient storage pointer.
    function load(address who) internal pure returns (Data storage feeRecipient) {
        bytes32 slot = keccak256(abi.encode(FEE_RECIPIENT_LOCATION, who));
        assembly {
            feeRecipient.slot := slot
        }
    }
}
