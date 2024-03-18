// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { IFeeManager, FeeAsset } from "../interfaces/IFeeManager.sol";
import { IVerifierProxy } from "../interfaces/IVerifierProxy.sol";
import { ChainlinkUtil } from "../ChainlinkUtil.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { IPerpsEngine } from "@zaros/markets/perps/interfaces/IPerpsEngine.sol";
import { ISettlementModule } from "@zaros/markets/perps/interfaces/ISettlementModule.sol";

// Open Zeppelin dependencies
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";

abstract contract BaseUpkeep is UUPSUpgradeable, OwnableUpgradeable {
    /// @notice ERC7201 storage location.
    bytes32 internal constant BASE_UPKEEP_LOCATION = keccak256(
        abi.encode(uint256(keccak256("fi.zaros.external.chainlink.upkeeps.BaseUpkeep")) - 1)
    ) & ~bytes32(uint256(0xff));

    /// @notice Chainlink Data Streams Reports default decimals (both Basic and Premium).
    uint8 internal constant REPORT_PRICE_DECIMALS = 8;

    /// @custom:storage-location erc7201:fi.zaros.external.chainlink.BaseUpkeep
    /// @param forwarder The address of the Upkeep forwarder contract.
    struct BaseUpkeepStorage {
        address forwarder;
    }

    /// @notice Ensures that only the Upkeep's forwarder contract can call a function.
    modifier onlyForwarder() {
        BaseUpkeepStorage storage self = _getBaseUpkeepStorage();
        bool isSenderForwarder = msg.sender == self.forwarder;

        if (!isSenderForwarder) {
            revert Errors.Unauthorized(msg.sender);
        }
        _;
    }

    /// @notice Updates the Upkeep forwarder address.
    /// @param forwarder The new forwarder address.
    function setForwarder(address forwarder) external onlyOwner {
        BaseUpkeepStorage storage self = _getBaseUpkeepStorage();
        self.forwarder = forwarder;
    }

    /// @notice {BaseUpkeep} UUPS initializer.
    function __BaseUpkeep_init(address owner) internal onlyInitializing {
        if (owner == address(0)) {
            revert Errors.ZeroInput("owner");
        }

        __Ownable_init(owner);
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
