// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { ILiquidityEngine } from "@zaros/liquidity/interfaces/ILiquidityEngine.sol";
import { IBalancerVault, IAsset } from "@zaros/external/balancer/interfaces/IBalancerVault.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { IStrategy } from "./interfaces/IStrategy.sol";

// Open Zeppelin dependencies
import { ERC4626, IERC4626, ERC20, IERC20 } from "@openzeppelin/token/ERC20/extensions/ERC4626.sol";
import { SafeERC20 } from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/utils/ReentrancyGuard.sol";

contract BalancerUSDCStrategy is IStrategy, ERC4626, ReentrancyGuard {
    using SafeERC20 for IERC20;

    address private _liquidityEngine;
    address private _usdToken;
    address private _balancerVault;
    uint256 private _totalUsdcAllocated;
    bytes32 private _usdTokenUsdcPoolId;

    modifier onlyLiquidityEngine() {
        if (msg.sender != _liquidityEngine) {
            revert Errors.Unauthorized(msg.sender);
        }
        _;
    }

    constructor(
        address liquidityEngine,
        address usdc,
        address usdToken,
        address balancerVault,
        bytes32 usdTokenUsdcPoolId
    )
        ERC4626(IERC20(usdc))
        ERC20("Zaros USDz/USDC Balancer Strategy", "USDz/USDC-BAL")
    {
        _liquidityEngine = liquidityEngine;
        _usdToken = usdToken;
        _balancerVault = balancerVault;
        _usdTokenUsdcPoolId = usdTokenUsdcPoolId;
    }

    function totalAssets() public view override(IERC4626, ERC4626) returns (uint256) {
        // TODO: query usdc balance on balancer pool
        // TODO: https://docs.balancer.fi/reference/contracts/query-functions.html
        return super.totalAssets() + _totalUsdcAllocated;
    }

    function setAllowances(uint256 amount, bool shouldIncrease) external override onlyLiquidityEngine {
        IERC20 usdc = IERC20(address(asset()));
        IERC20 usdToken = IERC20(address(_usdToken));
        address balancerVault = _balancerVault;
        if (shouldIncrease) {
            usdc.safeIncreaseAllowance(balancerVault, amount);
            usdToken.safeIncreaseAllowance(balancerVault, amount);
        } else {
            usdc.safeDecreaseAllowance(balancerVault, amount);
            usdToken.safeDecreaseAllowance(balancerVault, amount);
        }
    }

    function deposit(
        uint256 assets,
        address receiver
    )
        public
        override(IERC4626, ERC4626)
        nonReentrant
        onlyLiquidityEngine
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
        onlyLiquidityEngine
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
        onlyLiquidityEngine
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
        onlyLiquidityEngine
        returns (uint256)
    {
        return super.redeem(shares, receiver, owner);
    }

    /// TODO: Implement in new async flow
    function collectRewards(uint256[] calldata minAmountsOut) external override onlyLiquidityEngine returns (uint256) {
        return 0;
    }

    function addLiquidityToPool(uint256 minBptOut) external override onlyLiquidityEngine {
        address usdc = asset();
        uint256 outstandingUsdc = IERC20(usdc).balanceOf(address(this));
        uint256 usdTokenAmountToBorrow = _normalizeAssetToUsdToken(outstandingUsdc);
        ILiquidityEngine(_liquidityEngine).mintUsdToStrategy(usdc, usdTokenAmountToBorrow);

        // Forms Balancer Join Pool Request
        IAsset[] memory assets = _getAssets();

        uint256[] memory maxAmountsIn = new uint256[](2);
        maxAmountsIn[0] = outstandingUsdc;
        maxAmountsIn[1] = usdTokenAmountToBorrow;

        _totalUsdcAllocated += outstandingUsdc;
        IBalancerVault(_balancerVault).joinPool(
            _usdTokenUsdcPoolId,
            address(this),
            address(this),
            IBalancerVault.JoinPoolRequest(
                assets,
                maxAmountsIn,
                abi.encode(IBalancerVault.JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT, maxAmountsIn, minBptOut),
                false
            )
        );
    }

    function removeLiquidityFromPool(
        uint256 bptAmountIn,
        uint256[] calldata minAmountsOut
    )
        external
        override
        onlyLiquidityEngine
    {
        // Forms Balancer Exit Pool Request
        IAsset[] memory assets = _getAssets();

        _totalUsdcAllocated -= minAmountsOut[0];
        IBalancerVault(_balancerVault).exitPool(
            _usdTokenUsdcPoolId,
            address(this),
            payable(address(this)),
            IBalancerVault.ExitPoolRequest(
                assets,
                minAmountsOut,
                abi.encode(IBalancerVault.ExitKind.EXACT_BPT_IN_FOR_TOKENS_OUT, bptAmountIn),
                false
            )
        );
    }

    function _normalizeAssetToUsdToken(uint256 assetAmount) internal view returns (uint256) {
        uint256 usdcDecimals = ERC20(asset()).decimals();
        uint256 usdTokenDecimals = ERC20(_usdToken).decimals();
        return assetAmount * (10 ** usdTokenDecimals) / (10 ** usdcDecimals);
    }

    function _getAssets() internal view returns (IAsset[] memory) {
        IAsset[] memory assets = new IAsset[](2);
        assets[0] = IAsset(asset());
        assets[1] = IAsset(_usdToken);

        return assets;
    }
}
