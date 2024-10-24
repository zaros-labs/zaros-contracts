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
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

contract StabilityBranch {
    using Collateral for Collateral.Data;
    using SafeERC20 for IERC20;
    using SafeCast for uint256;
    using UsdTokenSwap for UsdTokenSwap.Data;
    using StabilityConfiguration for StabilityConfiguration.Data;

    /// @notice Emitted to trigger the Chainlink Log based upkeep
    event LogInitiateSwap(address indexed caller, uint128 indexed requestId);

    /// @notice Emitted when a swap is not fulfilled by the keeper and assets are refunded
    event LogRefundSwap(address indexed user, uint128 indexed requestId);

    /// @notice Emitted when a swap is fulfilled by the keeper
    event LogFulfillSwap(address indexed user, uint128 indexed requestId);

    modifier onlyKeeper() {
        MarketMakingEngineConfiguration.Data storage configuration = MarketMakingEngineConfiguration.load();

        if (!configuration.isSystemKeeperEnabled[msg.sender]) {
            revert Errors.KeeperNotEnabled(msg.sender);
        }

        _;
    }

    /// @notice Initiates multiple (or one) USD token swap requests for the specified vaults and amounts.
    /// @param vaultIds An array of vault IDs from which to take assets.
    /// @param amountsIn An array of USD token amounts to be swapped from the user.
    /// @param minAmountsOut An array of minimum acceptable amounts of collateral the user expects to receive for each
    /// swap.
    /// @dev Swap is fulfilled by a registered keeper.
    /// @dev Invariants involved in the call:
    /// The arrays lengths MUST match
    /// The vaults MUST be of the same asset
    function initiateSwap(
        uint128[] calldata vaultIds,
        uint256[] calldata amountsIn,
        uint256[] calldata minAmountsOut
    )
        external
    {
        _validateSwapData(vaultIds, amountsIn, minAmountsOut);

        // load market making engine config
        MarketMakingEngineConfiguration.Data storage configuration = MarketMakingEngineConfiguration.load();

        // Load the first vault to store the initial collateral asset for comparison
        Vault.Data storage initialVault = Vault.load(vaultIds[0]);

        // load Usd token swap data
        UsdTokenSwap.Data storage tokenSwapData = UsdTokenSwap.load();

        for (uint256 i = 0; i < amountsIn.length; i++) {
            // transfer USD: user => address(this) - burned in fulfillSwap
            IERC20(configuration.usdTokenOfEngine[address(this)]).safeTransferFrom(
                msg.sender, address(this), amountsIn[i]
            );

            // get next request id for user
            uint128 requestId = tokenSwapData.nextId(msg.sender);

            // load swap request
            UsdTokenSwap.SwapRequest storage swapRequest = tokenSwapData.swapRequests[msg.sender][requestId];

            // Set swap request parameters
            swapRequest.minAmountOut = minAmountsOut[i];
            swapRequest.vaultId = vaultIds[i];
            swapRequest.assetOut = initialVault.collateral.asset;
            swapRequest.deadline = uint128(block.timestamp + tokenSwapData.maxExecutionTime);
            swapRequest.amountIn = amountsIn[i].toUint128();

            emit LogInitiateSwap(msg.sender, requestId);
        }
    }

    /// @notice Fulfills a USD token swap request by converting the specified amount of USD tokens to a collateral
    /// asset.
    /// @param user The address of the user who initiated the swap request.
    /// @param requestId The unique ID of the swap request made by the user.
    /// @param priceData The off-chain price data provided by Chainlink, encoded in calldata.
    /// @dev Called by data streams powered keeper.
    /// @dev Invariants involved in the call:
    /// The swap request MUST NOT have been processed
    /// MUST apply fees when swap is fulfilled
    /// The number of received assets MUST be greater than or equal to min assets.
    /// MUST only be callable by a registered keeper
    function fulfillSwap(
        address user,
        uint128 requestId,
        bytes calldata priceData,
        address engine
    )
        external
        onlyKeeper
    {
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
        UsdToken usdToken = UsdToken(marketMakingEngineConfiguration.usdTokenOfEngine[engine]);

        // load Stability configuration data
        StabilityConfiguration.Data storage data = StabilityConfiguration.load();

        // get price from report in 18 dec
        UD60x18 priceX18 = data.verifyOffchainPrice(priceData);

        // deduct fee
        uint256 amountInAfterFee = _handleFeeUsd(request.amountIn, false, usdToken);

        // get amount out asset
        uint256 amountOut = _getAmountOutCollateral(amountInAfterFee, priceX18);

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

        emit LogFulfillSwap(user, requestId);
    }

    /// @notice Refunds a swap request that has not been processed and has expired.
    /// @param requestId The unique ID of the swap request to be refunded.
    function refundSwap(uint128 requestId, address engine) external {
        // load swap data
        UsdTokenSwap.Data storage tokenSwapData = UsdTokenSwap.load();

        // load swap request
        UsdTokenSwap.SwapRequest storage request = tokenSwapData.swapRequests[msg.sender][requestId];

        // if request already procesed revert
        if (request.processed) {
            revert Errors.RequestAlreadyProcessed(msg.sender, requestId);
        }

        // if dealine has not yet passed revert
        if (request.deadline > block.timestamp) {
            revert Errors.RequestNotExpired(msg.sender, requestId);
        }

        // set precessed to true
        request.processed = true;

        // load Market making engine config
        MarketMakingEngineConfiguration.Data storage marketMakingEngineConfiguration =
            MarketMakingEngineConfiguration.load();

        // get usd token for engine
        address usdToken = marketMakingEngineConfiguration.usdTokenOfEngine[engine];

        // get refund amount
        uint256 refundAmount = _handleFeeUsd(request.amountIn, false, UsdToken(usdToken));

        // transfer usd refund amount back to user
        IERC20(usdToken).safeTransfer(msg.sender, refundAmount);

        emit LogRefundSwap(msg.sender, requestId);
    }

    /// @notice Calculates the amount of collateral to be received based on the input USD amount and the asset price.
    /// @param usdAmountIn The amount of USD tokens to be swapped.
    /// @param priceX18 The price of the collateral asset in 18-decimal fixed-point format (UD60x18).
    /// @return The amount of collateral to be received, calculated from the input USD amount and asset price.
    function _getAmountOutCollateral(uint256 usdAmountIn, UD60x18 priceX18) internal pure returns (uint256) {
        // uint256 -> SD59x18
        SD59x18 usdAmountInX18 = sd59x18(usdAmountIn.toInt256());

        // UD60x18 -> SD59x18
        SD59x18 assetPriceX18 = priceX18.intoSD59x18(); // TODO: Apply premium/discount

        // get amounts out taking into consideration CL price
        SD59x18 amountOutX18 = usdAmountInX18.div(assetPriceX18);

        // SD59x18 -> uint256
        return amountOutX18.intoUint256();
    }

    /// @notice Applies the swap fee to the USD token amount and either mints or transfers the fee to the fee
    /// recipient.
    /// @param amountIn The original amount of USD tokens to be swapped, before the fee is deducted.
    /// @param mintOrTransfer A boolean flag indicating whether the fee should be minted (`true`) or transferred
    /// (`false`).
    /// @param usdToken The USD token contract used in the swap.
    /// @return The amount of USD tokens remaining after the fee is deducted.
    function _handleFeeUsd(uint256 amountIn, bool mintOrTransfer, UsdToken usdToken) internal returns (uint256) {
        // load swap data
        UsdTokenSwap.Data storage tokenSwapData = UsdTokenSwap.load();

        // Calculate the total fee
        uint256 feeAmount = tokenSwapData.baseFee + (amountIn * tokenSwapData.swapSettlementFeeBps) / 10_000;

        // deduct the fee from the amountIn
        amountIn -= feeAmount;

        if (mintOrTransfer) {
            // mint fee too fee recipient
            UsdToken(usdToken).mint(address(1), feeAmount); // TODO: set recipient
        } else {
            // transfer fee too fee recipient
            IERC20(usdToken).safeTransfer(address(1), feeAmount); // TODO: set recipient
        }

        // return amountIn after fee was applied
        return amountIn;
    }

    /// @notice Validates the input data for initiating a swap.
    /// @param vaultIds An array of vault IDs that the swap will involve.
    /// @param amountsIn An array of USD token amounts to be swapped from the user.
    /// @param minAmountsOut An array of minimum acceptable amounts of collateral to be received.
    function _validateSwapData(
        uint128[] calldata vaultIds,
        uint256[] calldata amountsIn,
        uint256[] calldata minAmountsOut
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

        // load collateral data
        Collateral.Data storage collateral = Collateral.load(initialVault.collateral.asset);

        // Ensure the collateral asset is enabled
        collateral.verifyIsEnabled();

        // Ensure all vaults are of the same asset
        for (uint256 i = 0; i < amountsIn.length; i++) {
            // load vault by id
            Vault.Data storage vault = Vault.load(vaultIds[i]);

            // if assets are different revert
            if (vault.collateral.asset != initialVault.collateral.asset) {
                revert Errors.MissmatchingCollateralAssets(vault.collateral.asset, initialVault.collateral.asset);
            }
        }
    }

    /// @notice Retrieves a specific USD token swap request for a given user and request ID.
    /// @param caller The address of the user who initiated the swap request.
    /// @param requestId The unique ID of the swap request being retrieved.
    /// @return request The `SwapRequest` structure containing the details of the swap request.
    function getSwapRequest(
        address caller,
        uint128 requestId
    )
        external
        view
        returns (UsdTokenSwap.SwapRequest memory request)
    {
        UsdTokenSwap.Data storage tokenSwapData = UsdTokenSwap.load();

        request = tokenSwapData.swapRequests[caller][requestId];
    }
}
