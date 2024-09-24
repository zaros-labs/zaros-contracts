// SPDX-License-Identifier: UNLCICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";

// Open Zeppelin Upgradeable dependencies
import { Initializable } from "@openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ERC4626Upgradeable } from "@openzeppelin-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";

contract ZLPVault is Initializable, UUPSUpgradeable, OwnableUpgradeable, ERC4626Upgradeable {
    /// @custom:storage-location erc7201:openzeppelin.storage.ZLPVault
    struct ZLPVaultStorage {
        address marketMakingEngine;
        uint8 decimalsOffset;
    }

    /// @notice ERC-7201 namespace storage location.
    bytes32 private constant ZLPVaultStorageLocation =
        keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ZLPVault")) - 1)) & ~bytes32(uint256(0xff));

    modifier onlyMarketMakingEngine() {
        ZLPVaultStorage storage zlpVaultStorage = _getZLPVaultStorage();

        if (msg.sender != zlpVaultStorage.marketMakingEngine) {
            revert Errors.Unauthorized(msg.sender);
        }
        _;
    }

    function initialize(
        address marketMakingEngine,
        uint8 decimalsOffset,
        address owner,
        IERC20 asset_
    )
        external
        initializer
    {
        __Ownable_init(owner);
        __ERC4626_init(asset_);

        ZLPVaultStorage storage zlpVaultStorage = _getZLPVaultStorage();
        zlpVaultStorage.marketMakingEngine = marketMakingEngine;
        zlpVaultStorage.decimalsOffset = decimalsOffset;
    }

    function _getZLPVaultStorage() private pure returns (ZLPVaultStorage storage zlpVaultStorage) {
        bytes32 slot = ZLPVaultStorageLocation;
        assembly {
            zlpVaultStorage.slot := slot
        }
    }

    function deposit(uint256 assets, address receiver) public override onlyMarketMakingEngine returns (uint256) {
        return super.deposit(assets, receiver);
    }

    function mint(uint256 shares, address receiver) public override onlyMarketMakingEngine returns (uint256) {
        return super.mint(shares, receiver);
    }

    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    )
        public
        override
        onlyMarketMakingEngine
        returns (uint256)
    {
        return super.withdraw(assets, receiver, owner);
    }

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    )
        public
        override
        onlyMarketMakingEngine
        returns (uint256)
    {
        return super.redeem(shares, receiver, owner);
    }

    /// @notice Returns the decimals offset for the Vault
    /// Overridden and used in ERC4626
    /// @return The decimal offset for the Vault
    function _decimalsOffset() internal pure override returns (uint8) {
        ZLPVaultStorage memory zlpVaultStorage = _getZLPVaultStorage();
        return zlpVaultStorage.decimalsOffset;
    }

    function _authorizeUpgrade(address) internal override onlyOwner { }
}
