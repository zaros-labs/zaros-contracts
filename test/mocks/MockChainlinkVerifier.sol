// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

contract MockChainlinkVerifier {
    address public immutable s_feeManager;

    constructor(address feeManager) {
        s_feeManager = feeManager;
    }

    function verify(
        bytes calldata payload,
        bytes calldata parameterPayload
    )
        external
        payable
        returns (bytes memory verifierResponse)
    {
        return abi.encode(payload);
    }
}
