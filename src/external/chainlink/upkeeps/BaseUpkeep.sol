// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { PerpsEngine } from "@zaros/markets/perps/PerpsEngine.sol";

// Open Zeppelin dependencies
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";

abstract contract BaseUpkeep is UUPSUpgradeable, OwnableUpgradeable {
    /// @notice ERC7201 storage location.
    bytes32 internal constant BASE_UPKEEP_LOCATION = keccak256(
        abi.encode(uint256(keccak256("fi.zaros.external.chainlink.upkeeps.BaseUpkeep")) - 1)
    ) & ~bytes32(uint256(0xff));

    /// @custom:storage-location erc7201:fi.zaros.external.chainlink.BaseUpkeep
    /// @param chainlinkVerifier The address of the Chainlink Verifier contract.
    /// @param forwarder The address of the Upkeep forwarder contract.
    /// @param perpsEngine The address of the PerpsEngine contract.
    struct BaseUpkeepStorage {
        address chainlinkVerifier;
        address forwarder;
        PerpsEngine perpsEngine;
    }

    modifier onlyPerpsEngine() {
        BaseUpkeepStorage storage self = _getBaseUpkeepStorage();
        bool isSenderPerpsEngine = msg.sender == address(self.perpsEngine);

        if (!isSenderPerpsEngine) {
            revert Errors.Unauthorized(msg.sender);
        }
        _;
    }

    /// @notice {BaseUpkeep} UUPS initializer.
    function initialize(address chainlinkVerifier, address forwarder, PerpsEngine perpsEngine) external initializer {
        __Ownable_init(msg.sender);

        if (chainlinkVerifier == address(0)) {
            revert Errors.ZeroInput("chainlinkVerifier");
        }
        if (forwarder == address(0)) {
            revert Errors.ZeroInput("forwarder");
        }
        if (address(perpsEngine) == address(0)) {
            revert Errors.ZeroInput("perpsEngine");
        }

        BaseUpkeepStorage storage self = _getBaseUpkeepStorage();

        self.chainlinkVerifier = chainlinkVerifier;
        self.forwarder = forwarder;
        self.perpsEngine = perpsEngine;
    }

    function getConfig()
        external
        view
        returns (address upkeepOwner, address chainlinkVerifier, address forwarder, address perpsEngine)
    {
        BaseUpkeepStorage storage self = _getBaseUpkeepStorage();

        upkeepOwner = owner();
        chainlinkVerifier = self.chainlinkVerifier;
        forwarder = self.forwarder;
        perpsEngine = address(self.perpsEngine);
    }

    function _getBaseUpkeepStorage() internal pure returns (BaseUpkeepStorage storage self) {
        bytes32 slot = BASE_UPKEEP_LOCATION;

        assembly {
            self.slot := slot
        }
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address) internal override onlyOwner { }
}
