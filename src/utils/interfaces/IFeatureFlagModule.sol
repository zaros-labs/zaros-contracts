//SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

interface IFeatureFlagBranch {
    event FeatureFlagAllowAllSet(bytes32 indexed feature, bool allowAll);

    event FeatureFlagDenyAllSet(bytes32 indexed feature, bool denyAll);

    event FeatureFlagAllowlistAdded(bytes32 indexed feature, address account);

    event FeatureFlagAllowlistRemoved(bytes32 indexed feature, address account);

    event FeatureFlagDeniersReset(bytes32 indexed feature, address[] deniers);

    function setFeatureFlagAllowAll(bytes32 feature, bool allowAll) external;

    function setFeatureFlagDenyAll(bytes32 feature, bool denyAll) external;

    function addToFeatureFlagAllowlist(bytes32 feature, address account) external;

    function removeFromFeatureFlagAllowlist(bytes32 feature, address account) external;

    function setDeniers(bytes32 feature, address[] memory deniers) external;

    function getDeniers(bytes32 feature) external returns (address[] memory);

    function getFeatureFlagAllowAll(bytes32 feature) external view returns (bool);

    function getFeatureFlagDenyAll(bytes32 feature) external view returns (bool);

    function getFeatureFlagAllowlist(bytes32 feature) external view returns (address[] memory);

    function isFeatureAllowed(bytes32 feature, address account) external view returns (bool);
}
