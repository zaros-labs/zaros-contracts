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

// @title A contract to manage the user access trough the generated keys
// @author Zaros Labs
contract AccessKeyManager is OwnableUpgradeable,  UUPSUpgradeable {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;
    using SignatureChecker for address;

    address public spearmintSigner;

    struct AttestationData {
        uint256 availableKeys;
    }

    struct GeneratedKey {
        uint96 id;
        bytes16 key;
    }

    struct KeyData {
        address creator;
        bool isAvailable;
    }

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

    // @notice Create new available key
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

    // @notice Get your generated keys
    function getKeysByUser() external view returns (GeneratedKey[] memory) {
        return userGeneratedKeys[msg.sender];
    }

    // @notice Active your key
    function activateKey(bytes16 key) external {
        if (!keys[key].isAvailable) {
            revert InvalidKey();
        }

        keys[key].isAvailable = false;
        keyIdOfUser[msg.sender] = key;
    }

    // @notice Verify if user have access
    function isUserActive() external view returns (bool) {
        return keyIdOfUser[msg.sender] != bytes16(0);
    }

    // @notice Verify if user key is valid
    function isKeyValid(bytes16 key) external view returns (bool) {
        return keys[key].isAvailable;
    }

    // @notice Get the data of key
    function getKeyData(bytes16 key) external view returns (KeyData memory) {
        return keys[key];
    }

    // @notice Update spearmint signer
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
