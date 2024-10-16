// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Collateral } from "@zaros/market-making/leaves/Collateral.sol";
import { Vault } from "@zaros/market-making/leaves/Vault.sol";
import { UsdToken } from "@zaros/usd/UsdToken.sol";
import { MarketMakingEngineConfiguration } from "@zaros/market-making/leaves/MarketMakingEngineConfiguration.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { Math } from "@zaros/utils/Math.sol";
import { UsdTokenSwap } from "@zaros/market-making/leaves/UsdTokenSwap.sol";
import { StabilityConfiguration } from "@zaros/market-making/leaves/StabilityConfiguration.sol";

// Open Zeppelin dependencies
import { IERC20, SafeERC20 } from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import { IERC4626 } from "@openzeppelin/token/ERC20/extensions/ERC4626.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

contract StabilityBranch {
    using Collateral for Collateral.Data;
    using SafeERC20 for IERC20;
    using SafeCast for uint256;
    using UsdTokenSwap for UsdTokenSwap.Data;
    using Collateral for Collateral.Data;
    using StabilityConfiguration for StabilityConfiguration.Data;

    /// @notice Emitted to trigger the Chainlink Log based upkeep
    event LogInitiateSwap(address indexed caller, uint128 indexed requestId);

    /// @notice Emitted when a swap is not fulfilled by the keeper and assets are refunded
    event LogRefundSwap(address indexed user, uint128 indexed requestId);

    /// @notice Emitted when a swap is fulfilled by the keeper
    event LogFulfillSwap(address indexed user, uint128 indexed requestId);

    modifier onlyKeeper(address caller) {
        MarketMakingEngineConfiguration.Data storage configuration = MarketMakingEngineConfiguration.load();

        if (!configuration.isSystemKeeperEnabled[caller]) revert Errors.KeeperNotEnabled(caller);
        _;
    }

    /// @dev Swap is fulfilled by a registered keeper.
    /// @dev Invariants involved in the call:
    /// @dev the asset transfer and / or USDz burn from the msg.sender must happen during initiateSwap,
    /// and then fullfillSwap just updates the system state and performs the payment.
    /// TODO: add invariants
    function initiateSwap(
        uint128[] calldata vaultIds,
        uint256[] calldata amountsIn,
        uint128[] calldata minAmountsOut,
        address assetOut
    )
        external
    {
        _validateSwapData(vaultIds, amountsIn, minAmountsOut);

        MarketMakingEngineConfiguration.Data storage configuration = MarketMakingEngineConfiguration.load();

        // Load the first vault to store the initial collateral asset for comparison
        Vault.Data storage initialVault = Vault.load(vaultIds[0]);

        // load Usd token swap data
        UsdTokenSwap.Data storage tokenSwapData = UsdTokenSwap.load();

        for (uint256 i = 0; i < amountsIn.length; i++) {
            // collatral asset => USD Token
            if (assetOut == configuration.usdTokenOfEngine[msg.sender]) {
                // transfer asset: user => address(this)
                IERC20(initialVault.collateral.asset).safeTransferFrom(msg.sender, address(this), amountsIn[i]); // todo
                    // use credit deposit leaf
            }
            // USD Token => collatral asset
            else if (assetOut == initialVault.collateral.asset) {
                // transfer USD: user => address(this) - burned in fulfillSwap
                IERC20(configuration.usdTokenOfEngine[msg.sender]).safeTransferFrom(
                    msg.sender, address(this), amountsIn[i]
                );
            }
            // swap not supported
            else {
                revert Errors.UnsupportedAssetOut(assetOut);
            }

            // get next request id for user
            uint128 requestId = tokenSwapData.nextId(msg.sender);

            // load swap request
            UsdTokenSwap.SwapRequest storage swapRequest = tokenSwapData.swapRequests[msg.sender][requestId];

            // Set swap request parameters
            swapRequest.minAmountOut = minAmountsOut[i];
            swapRequest.vaultId = vaultIds[i];
            swapRequest.assetOut = assetOut;
            swapRequest.deadline = uint128(block.timestamp + tokenSwapData.maxExecutionTime);
            swapRequest.amountIn = amountsIn[i].toUint128();

            emit LogInitiateSwap(msg.sender, requestId);
        }
    }

    /// @dev Called by data streams powered keeper.
    /// @dev Invariants involved in the call:
    /// TODO: add invariants
    function fulfillSwap(address user, uint128 requestId, bytes calldata priceData) external onlyKeeper(msg.sender) {
        // load request for user by id
        UsdTokenSwap.SwapRequest storage request = UsdTokenSwap.load().swapRequests[user][requestId];

        // revert if already processed
        if (request.processed) {
            revert Errors.RequestAlreadyProcessed(user, requestId);
        }

        // set request processed to true
        request.processed = true;

        // load market making engine config
        MarketMakingEngineConfiguration.Data storage marketMakingEngineConfiguration =
            MarketMakingEngineConfiguration.load();

        // load vault data
        Vault.Data storage vault = Vault.load(request.vaultId);

        // get usd token of engine
        UsdToken usdToken = UsdToken(marketMakingEngineConfiguration.usdTokenOfEngine[msg.sender]);

        // get price from report in 18 dec
        UD60x18 priceX18 = _getPrice(priceData);

        // collatral asset => USD Token
        if (request.assetOut == address(usdToken)) {
            // get amount out usd
            uint256 amountOut = _getAmountOutUsd(request.amountIn, request.vaultId, priceX18);

            // deduct fees and get mint amount
            amountOut = _handleFeeUsd(amountOut, true);

            // slippage check
            if (amountOut < request.minAmountOut) {
                revert Errors.SlippageCheckFailed();
            }

            // update vault debt
            vault.unsettledRealizedDebtUsd += int128(amountOut.toUint128()); // todo handle this conversion

            // mint usd amount
            usdToken.mint(msg.sender, amountOut);

            // address(this) => vault
            IERC20(vault.collateral.asset).safeTransfer(address(vault.indexToken), request.amountIn);
        }
        // USD Token => collatral asset
        else if (request.assetOut != address(usdToken)) {
            // get amount out asset
            uint256 amountOut = _getAmountOutCollateral(request.vaultId, request.amountIn, priceX18);

            // deduct fees and get asset amount
            amountOut = _handleFeeAsset(amountOut, request.assetOut);

            // slippage check
            if (amountOut < request.minAmountOut) {
                revert Errors.SlippageCheckFailed();
            }

            // burn usd amount from address(this)
            usdToken.burn(request.amountIn);

            // update vault debt
            vault.settledRealizedDebtUsd += int128(request.amountIn);

            // vault => user
            IERC20(vault.collateral.asset).safeTransferFrom(address(vault.indexToken), user, amountOut);
        }

        emit LogFulfillSwap(msg.sender, requestId);
    }

    function refundSwap(uint128 requestId) external {
        // load swap data
        UsdTokenSwap.Data storage tokenSwapData = UsdTokenSwap.load();

        // load swap request
        UsdTokenSwap.SwapRequest storage request = tokenSwapData.swapRequests[msg.sender][requestId];

        // if request already procesed revert
        if (request.processed) {
            revert Errors.RequestAlreadyProcessed(msg.sender, requestId);
        }

        // if dealine hasnot yet passed revert
        if (request.deadline < block.timestamp) {
            revert Errors.RequestNotExpired(msg.sender, requestId);
        }

        // set precessed to true
        request.processed = true;

        // load Market making engine config
        MarketMakingEngineConfiguration.Data storage marketMakingEngineConfiguration =
            MarketMakingEngineConfiguration.load();

        // get usd token for engine
        address usdToken = marketMakingEngineConfiguration.usdTokenOfEngine[msg.sender];

        // load vault
        Vault.Data storage vaultData = Vault.load(request.vaultId);

        // if swap asset out is usd token, refund collateral asset
        if (request.assetOut == usdToken) {
            // get refund amount
            uint256 refundAmount = _handleFeeAsset(request.amountIn, request.assetOut);

            // transfer asset refund amount back to user
            IERC20(vaultData.collateral.asset).safeTransfer(msg.sender, refundAmount);
        }

        // if swap asset out is collateral, refund usd token
        if (request.assetOut != usdToken) {
            // get refund amount
            uint256 refundAmount = _handleFeeUsd(request.amountIn, false);

            // transfer usd refund amount back to user
            IERC20(usdToken).safeTransfer(msg.sender, refundAmount);
        }

        emit LogRefundSwap(msg.sender, requestId);
    }

    function _getAmountOutUsd(uint128 vaultId, uint256 assetAmountIn, UD60x18 priceX18) internal view returns (uint256) {
        // load vault data
        Vault.Data storage vault = Vault.load(vaultId);

        // convert total debt to 18 dec
        SD59x18 unsettledDebtX18 = sd59x18(vault.unsettledRealizedDebtUsd);

        // load collateral data
        Collateral.Data storage collateral = vault.collateral;

        // UD60x18 -> SD59x18
        SD59x18 assetPriceX18 = priceX18.intoSD59x18();

        // uint256 -> SD59x18
        SD59x18 assetAmountInX18 = collateral.convertTokenAmountToSd59x18(assetAmountIn.toInt256());

        // get amounts out taking into consideration CL price
        SD59x18 usdAmountOutX18 = assetAmountInX18.mul(assetPriceX18);

        // get amount of assets that are credited
        SD59x18 assetsCreditX18 = unsettledDebtX18.div(assetPriceX18);

        // get vault total assets
        uint256 totalAssets = IERC4626(vault.indexToken).totalAssets();

        // uint256 -> SD59x18
        SD59x18 totalAssetsX18 = sd59x18(totalAssets.toInt256());

        // get amount credit based on default amountOut and vault (assets credit / total assets) ratio
        SD59x18 amountOutCreditX18 = usdAmountOutX18.mul(assetsCreditX18).div(totalAssetsX18);

        // subtract credited amount from default amount out
        usdAmountOutX18 = usdAmountOutX18.sub(amountOutCreditX18);

        // SD59x18 -> uint256
        return usdAmountOutX18.intoUint256();
    }

    function _getAmountOutCollateral(uint128 vaultId, uint256 usdAmountIn, UD60x18 priceX18) internal view returns (uint256) {
        // uint256 -> SD59x18
        SD59x18 usdAmountInX18 = sd59x18(usdAmountIn.toInt256());

        // load vault data
        Vault.Data storage vault = Vault.load(vaultId);

        // convert total debt to 18 dec
        SD59x18 unsettledDebtX18 = sd59x18(vault.unsettledRealizedDebtUsd);

        // UD60x18 -> SD59x18
        SD59x18 assetPriceX18 = priceX18.intoSD59x18();

        // get amount of assets that are credited
        SD59x18 assetsCreditX18 = unsettledDebtX18.div(assetPriceX18);

        // get amounts out taking into consideration CL price
        SD59x18 amountOutX18 = usdAmountInX18.div(assetPriceX18);

        // get vault total assets
        uint256 totalAssets = IERC4626(vault.indexToken).totalAssets();

        // uint256 -> SD59x18
        SD59x18 totalAssetsX18 = sd59x18(totalAssets.toInt256());

        // get amount credit based on default amountOut and vault (assets credit / total assets) ratio
        SD59x18 amountOutCreditX18 = amountOutX18.mul(assetsCreditX18).div(totalAssetsX18);

        // subtract credited amount from default amount out
        amountOutX18 = amountOutX18.sub(amountOutCreditX18);

        // SD59x18 -> uint256
        return amountOutX18.intoUint256();
    }

    function _handleFeeUsd(uint256 amountIn, bool mintOrTransfer) internal returns (uint256) {
        // load market making engine config
        MarketMakingEngineConfiguration.Data storage marketMakingEngineConfiguration =
            MarketMakingEngineConfiguration.load();

        // get usd token for engine
        address usdToken = marketMakingEngineConfiguration.usdTokenOfEngine[msg.sender];

        // load swap data
        UsdTokenSwap.Data storage tokenSwapData = UsdTokenSwap.load();

        // Calculate the total fee
        uint256 feeAmount = tokenSwapData.baseFee + (amountIn * tokenSwapData.swapSettlementFeeBps) / 10_000;

        // deduct the fee from the amountIn
        amountIn -= feeAmount;

        if (mintOrTransfer) {
            // mint fee too fee recipient
            UsdToken(usdToken).mint(marketMakingEngineConfiguration.feeDistributor, feeAmount);
        } else {
            // transfer fee too fee recipient
            IERC20(usdToken).safeTransfer(marketMakingEngineConfiguration.feeDistributor, feeAmount);
        }

        // return amountIn after fee was applied
        return amountIn;
    }

    function _handleFeeAsset(uint256 amountIn, address asset) internal returns (uint256) {
        // load market making engine config
        MarketMakingEngineConfiguration.Data storage marketMakingEngineConfiguration =
            MarketMakingEngineConfiguration.load();

        // load swap data
        UsdTokenSwap.Data storage tokenSwapData = UsdTokenSwap.load();

        // load collateral data
        Collateral.Data storage collateral = Collateral.load(asset);

        // get asset price
        UD60x18 priceX18 = collateral.getPrice();

        // get one UNIT of asset in 18 decimals
        UD60x18 oneAssetUnitX18 = collateral.convertTokenAmountToUd60x18(10 ** collateral.decimals);

        // get asset amount equal to 1 USD
        UD60x18 oneUsdAssetUnit = oneAssetUnitX18.div(priceX18);

        // UD60x18 -> uint256
        uint256 baseFeeAsset = collateral.convertUd60x18ToTokenAmount(oneUsdAssetUnit);

        // calculate fee amount
        uint256 feeAmount = amountIn - baseFeeAsset - (amountIn * tokenSwapData.swapSettlementFeeBps) / 10_000;

        // deduct the fee from the amount in
        amountIn -= feeAmount;

        // transfer fee too fee recipient
        IERC20(asset).safeTransfer(marketMakingEngineConfiguration.feeDistributor, feeAmount);

        // return amountIn after fee was applied
        return amountIn;
    }

    function _validateSwapData(
        uint128[] calldata vaultIds,
        uint256[] calldata amountsIn,
        uint128[] calldata minAmountsOut
    )
        internal
        view
    {
        // Perform length checks
        if (vaultIds.length != amountsIn.length) {
            revert Errors.ArrayLengthMismatch(vaultIds.length, amountsIn.length);
        }

        if (amountsIn.length != minAmountsOut.length) {
            revert Errors.ArrayLengthMismatch(amountsIn.length, minAmountsOut.length);
        }

        // load first vault by id
        Vault.Data storage initialVault = Vault.load(vaultIds[0]);

        // Ensure the collateral asset is enabled
        initialVault.collateral.verifyIsEnabled();

        // Ensure all vaults are of the same asset
        for (uint256 i = 0; i < amountsIn.length; i++) {
            // load vault by id
            Vault.Data storage vault = Vault.load(vaultIds[i]);

            // if assets are different revert
            if (vault.collateral.asset == initialVault.collateral.asset) {
                revert Errors.MissmatchingCollateralAssets(vault.collateral.asset, initialVault.collateral.asset);
            }
        }
    }

    function _getPrice(bytes calldata priceData) internal returns (UD60x18) {
        StabilityConfiguration.Data storage data = StabilityConfiguration.load();

        return data.verifyOffchainPrice(priceData);
    }
}
