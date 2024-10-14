// SPDX-License-Identifier: UNLCICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Vault } from "@zaros/market-making/leaves/Vault.sol";
import { IMarketMakingEngine } from "@zaros/market-making/MarketMakingEngine.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";

// Open Zeppelin Upgradeable dependencies
import { Initializable } from "@openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ERC4626Upgradeable } from "@openzeppelin-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

contract ZlpVault is Initializable, UUPSUpgradeable, OwnableUpgradeable, ERC4626Upgradeable {
    using Math for uint256;

    /// @custom:storage-location erc7201:openzeppelin.storage.ZlpVault
    struct ZlpVaultStorage {
        address marketMakingEngine;
        uint8 decimalsOffset;
        uint128 vaultId;
    }

    /// @notice ERC-7201 namespace storage location.
    bytes32 private constant ZlpVaultStorageLocation =
        keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ZlpVault")) - 1)) & ~bytes32(uint256(0xff));

    modifier onlyMarketMakingEngine() {
        ZlpVaultStorage storage zlpVaultStorage = _getZlpVaultStorage();

        if (msg.sender != zlpVaultStorage.marketMakingEngine) {
            revert Errors.Unauthorized(msg.sender);
        }
        _;
    }

    function initialize(
        address marketMakingEngine,
        uint8 decimalsOffset,
        address owner,
        IERC20 asset_,
        uint128 vaultId
    )
        external
        initializer
    {
        __Ownable_init(owner);
        __ERC4626_init(asset_);

        ZlpVaultStorage storage zlpVaultStorage = _getZlpVaultStorage();
        zlpVaultStorage.marketMakingEngine = marketMakingEngine;
        zlpVaultStorage.decimalsOffset = decimalsOffset;
        zlpVaultStorage.vaultId = vaultId;
    }

    function _getZlpVaultStorage() private pure returns (ZlpVaultStorage storage zlpVaultStorage) {
        bytes32 slot = ZlpVaultStorageLocation;
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
        ZlpVaultStorage memory zlpVaultStorage = _getZlpVaultStorage();
        return zlpVaultStorage.decimalsOffset;
    }

    function _convertToAssets(uint256 assets, Math.Rounding /**/ ) internal view override returns (uint256) {
        ZlpVaultStorage storage zlpVaultStorage = _getZlpVaultStorage();

        UD60x18 assetsOut = IMarketMakingEngine(zlpVaultStorage.marketMakingEngine).getIndexTokenSwapRate(
            zlpVaultStorage.vaultId, assets
        );

        return assetsOut.intoUint256();
    }

    function _convertToShares(
        uint256 shares,
        Math.Rounding
    )
        /*
        */
        internal
        view
        override
        returns (uint256)
    {
        ZlpVaultStorage storage zlpVaultStorage = _getZlpVaultStorage();

        UD60x18 sharesOut = IMarketMakingEngine(zlpVaultStorage.marketMakingEngine).getVaultAssetSwapRate(
            zlpVaultStorage.vaultId, shares
        );

        return sharesOut.intoUint256();
    }

    function _authorizeUpgrade(address) internal override onlyOwner { }
}
