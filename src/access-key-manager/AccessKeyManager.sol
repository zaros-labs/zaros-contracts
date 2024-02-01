// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract AccessKeyManager is Ownable {
    using ECDSA for bytes32;

    address public signer;
    uint96 nextKeyId;

    struct GeneratedKey {
        uint96 id;
        bytes16 key;
        uint256 timestamp;
    }

    mapping (address => GeneratedKey[]) userGeneratedKeys;
    mapping (bytes16 => bool) usedKeys;
    mapping (address => bool) usersActive;

    error InvalidSignature();

    constructor(address _signer) Ownable(msg.sender) {
        setSigner(_signer);
    }

    function createKey(bytes calldata _signature) external {
        if (!_verifySignature(msg.sender, _signature)) {
            revert InvalidSignature();
        }

        bytes16 key = bytes16(keccak256(abi.encode(msg.sender, ++nextKeyId)));

        GeneratedKey memory generatedKey;
        generatedKey.id = nextKeyId;
        generatedKey.key = key;
        generatedKey.timestamp = block.timestamp;

        userGeneratedKeys[msg.sender].push(generatedKey);
    }

    function activateKey(bytes16 key) external {
        require(!usedKeys[key], "Your key is already used");

        usedKeys[key] = true;
        usersActive[msg.sender] = true;
    }

    function userHasAccess() external view returns (bool) {
        return usersActive[msg.sender];
    }

    function isKeyValid(bytes16 key) external view returns (bool) {
        return usedKeys[key];
    }

    function setSigner(address _signer) public onlyOwner {
        signer = _signer;
    }

    function _verifySignature(address _addr, bytes calldata _signature) internal view returns (bool _isValid) {
        bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", keccak256(abi.encode(_addr))));
        _isValid = signer == digest.recover(_signature);
    }
}
