// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { IBalancerVault } from "@zaros/external/balancer/IBalancerVault.sol";
import { AddressError } from "@zaros/utils/Errors.sol";
import { IStrategy } from "./interfaces/IStrategy.sol";

// Open Zeppelin dependencies
import { ERC4626, IERC4626, ERC20, IERC20 } from "@openzeppelin/token/ERC20/extensions/ERC4626.sol";
import { SafeERC20 } from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/security/ReentrancyGuard.sol";

contract BalancerUSDCStrategy is IStrategy, ERC4626, ReentrancyGuard {
    using SafeERC20 for IERC20;

    address private _zaros;
    address private _zrsUsd;
    address private _balancerVault;
    uint256 private _totalUsdcInvested;
    bytes32 private _zrsUsdUsdcPoolId;

    modifier onlyZaros() {
        if (msg.sender != _zaros) {
            revert AddressError.Zaros_Unauthorized(msg.sender);
        }
        _;
    }

    constructor(
        address zaros,
        address usdc,
        address zrsUsd,
        address balancerVault,
        bytes32 zrsUsdUsdcPoolId
    )
        ERC4626(IERC20(usdc))
        ERC20("Zaros zrsUSD/USDC Balancer Strategy", "zrsUSD/USDC-BAL")
    {
        _zaros = zaros;
        _zrsUsd = zrsUsd;
        _balancerVault = balancerVault;
        _zrsUsdUsdcPoolId = zrsUsdUsdcPoolId;
    }

    function totalAssets() public view override(IERC4626, ERC4626) returns (uint256) {
        // TODO: query usdc balance on balancer pool
        return super.totalAssets();
        // return super.totalAssets() + _totalUsdcInvested;
    }

    function setAllowances(uint256 amount, bool shouldIncrease) external override onlyZaros {
        IERC20 usdc = IERC20(address(asset()));
        IERC20 zrsUsd = IERC20(address(_zrsUsd));
        address balancerVault = _balancerVault;
        if (shouldIncrease) {
            usdc.safeIncreaseAllowance(balancerVault, amount);
            zrsUsd.safeIncreaseAllowance(balancerVault, amount);
        } else {
            usdc.safeDecreaseAllowance(balancerVault, amount);
            zrsUsd.safeDecreaseAllowance(balancerVault, amount);
        }
    }

    function deposit(
        uint256 assets,
        address receiver
    )
        public
        override(IERC4626, ERC4626)
        nonReentrant
        onlyZaros
        returns (uint256)
    {
        return super.deposit(assets, receiver);
    }

    function mint(
        uint256 shares,
        address receiver
    )
        public
        override(IERC4626, ERC4626)
        nonReentrant
        onlyZaros
        returns (uint256)
    {
        return super.mint(shares, receiver);
    }

    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    )
        public
        override(IERC4626, ERC4626)
        nonReentrant
        onlyZaros
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
        override(IERC4626, ERC4626)
        nonReentrant
        onlyZaros
        returns (uint256)
    {
        return super.redeem(shares, receiver, owner);
    }

    function collectRewards(uint256 minLpOut) external override onlyZaros returns (uint256) { }

    function invest(uint256 mintLpOut) external override onlyZaros {
        address usdc = asset();
        uint256 outstandingUsdc = IERC20(usdc).balanceOf(address(this));
        uint256 zrsUsdAmountToBorrow = _normalizeAssetToZarosUsd(outstandingUsdc);
        uint256 zrsUsdBorrowed = IZaros(_zaros).mintUsdToStrategy(usdc, zrsUsdAmountToBorrow);

        // Forms Balancer Join Pool Request
        IBalancerVault.IAsset[] memory assets = new IAsset[](2);
        assets[0] = IAsset(usdc);
        assets[1] = IAsset(_zrsUsd);
        uint256[] memory maxAmountsIn = new uint256[](2);
        maxAmountsIn[0] = outstandingUsdc;
        maxAmountsIn[1] = zrsUsdAmountToBorrow;

        balVault.joinPool(
            _zrsUsdUsdcPoolId,
            address(this),
            address(this),
            IBalancerVault.JoinPoolRequest(
                assets,
                maxAmountsIn,
                abi.encode(IBalancerVault.JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT, _amountsIn, minLpOut),
                false
            )
        );
    }

    function _normalizeAssetToZarosUsd(uint256 assetAmount) internal view returns (uint256) {
        /// TODO: implement
        return uint256(1);
    }
}
