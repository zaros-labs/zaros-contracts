// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

/// @title A contract to manage the user access trough the generated keys.
interface IAccessKeyManager {

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

    error InvalidAttestation();

    /// @notice Create key with the validation of spearmint
    /// @param data The attestation data of spearmint
    /// @param _signature The signature from spearmint
    function createKey(AttestationData calldata data, bytes calldata _signature) external;

    /// @notice Get your generated keys
    /// @return Array of keys
    function getKeysByUser() external view returns (GeneratedKey[] memory);

    /// @notice Active user key
    /// @param key The key passed
    function activateKey(bytes16 key) external;

    /// @notice Verify if user have access
    /// @param user The user address
    /// @return The boolen if user has access
    function isUserActive(address user) external view returns (bool);

    /// @notice Verify if user key is valid
    /// @param key The key passed
    /// @return The boolen if key is valid
    function isKeyValid(bytes16 key) external view returns (bool);

    /// @notice Get the data of key
    /// @param key The key passed
    /// @return The data of key
    function getKeyData(bytes16 key) external view returns (KeyData memory);

    /// @notice Update spearmint signer
    /// @param _spearmintSigner The address of signer spearmint
    function setSpearmintSigner(address _spearmintSigner) external;
}
