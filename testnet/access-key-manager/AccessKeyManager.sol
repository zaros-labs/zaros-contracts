// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Open zeppelin dependencies
import "@openzeppelin/utils/cryptography/ECDSA.sol";
import "@openzeppelin/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/utils/cryptography/SignatureChecker.sol";

// Open zeppelin upgradeable dependencies
import { ERC20PermitUpgradeable } from "@openzeppelin-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";

// Zaros dependencies
import { IAccessKeyManager } from "./interfaces/IAccessKeyManager.sol";

contract AccessKeyManager is OwnableUpgradeable,  UUPSUpgradeable, IAccessKeyManager {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;
    using SignatureChecker for address;

    address public spearmintSigner;

    mapping (address user => GeneratedKey[] keys) public userGeneratedKeys;
    mapping (bytes16 key => KeyData data) public keys;
    mapping (address user => bytes16 key) public keyIdOfUser;

    error NotEnoughAvailableKeys(uint256 amountOfGeneratedKeys, uint256 availableKeys);
    error InvalidSignature();
    error InvalidKey();

    function initialize(address owner, address _spearmintSigner) external initializer {
        spearmintSigner = _spearmintSigner;

        __Ownable_init(owner);
    }

    function createKey(AttestationData calldata data, bytes calldata _signature) external {
        _validateSignature(data, _signature);

        uint256 amountOfGeneratedKeys = userGeneratedKeys[msg.sender].length;

        if (amountOfGeneratedKeys >= data.availableKeys) {
            revert NotEnoughAvailableKeys(amountOfGeneratedKeys, data.availableKeys);
        }

        for (uint256 i = amountOfGeneratedKeys; i < amountOfGeneratedKeys + data.availableKeys; i++) {
            bytes16 key = bytes16(keccak256(abi.encode(msg.sender, i)));

            userGeneratedKeys[msg.sender].push(GeneratedKey({
                id: uint96(i),
                key: key
            }));

            keys[key] = KeyData({
                creator: msg.sender,
                isAvailable: true
            });
        }
    }

    function getKeysByUser() external view returns (GeneratedKey[] memory) {
        return userGeneratedKeys[msg.sender];
    }

    function activateKey(bytes16 key) external {
        if (!keys[key].isAvailable) {
            revert InvalidKey();
        }

        keys[key].isAvailable = false;
        keyIdOfUser[msg.sender] = key;
    }

    function isUserActive(address user) external view returns (bool) {
        return keyIdOfUser[user] != bytes16(0);
    }

    function isKeyValid(bytes16 key) external view returns (bool) {
        return keys[key].isAvailable;
    }

    function getKeyData(bytes16 key) external view returns (KeyData memory) {
        return keys[key];
    }

    function setSpearmintSigner(address _spearmintSigner) public onlyOwner {
        spearmintSigner = _spearmintSigner;
    }

    function _validateSignature(
        AttestationData memory data,
        bytes calldata signature
    ) internal view {
        bytes32 hashedData = keccak256(abi.encode(msg.sender, data));

        if (
            !spearmintSigner.isValidSignatureNow(
                hashedData.toEthSignedMessageHash(),
                signature
            )
        ) {
            revert InvalidSignature();
        }
    }

    function _authorizeUpgrade(address) internal override onlyOwner { }
}
