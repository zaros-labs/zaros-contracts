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

contract AccessKeyManager is OwnableUpgradeable,  UUPSUpgradeable {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;
    using SignatureChecker for address;

    address public spearmintSigner;
    uint96 internal nextKeyId;

    struct AttestationData {
        uint256 availableKeys;
    }

    struct GeneratedKey {
        uint96 id;
        bytes16 key;
    }

    mapping (address user => GeneratedKey[] keys) public userGeneratedKeys;
    mapping (bytes16 key => bool status) public usedKeys;
    mapping (address user => bool status) public usersActive;

    error NotEnoughAvailableKeys(uint256 amountOfGeneratedKeys, uint256 availableKeys);
    error InvalidSignature();

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
        }
    }

    function getKeysByUser() external view returns (GeneratedKey[] memory) {
        return userGeneratedKeys[msg.sender];
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
