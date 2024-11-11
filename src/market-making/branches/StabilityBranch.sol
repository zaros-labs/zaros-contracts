// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { UsdToken } from "@zaros/usd/UsdToken.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { Math } from "@zaros/utils/Math.sol";
import { Collateral } from "@zaros/market-making/leaves/Collateral.sol";
import { Vault } from "@zaros/market-making/leaves/Vault.sol";
import { MarketMakingEngineConfiguration } from "@zaros/market-making/leaves/MarketMakingEngineConfiguration.sol";
import { UsdTokenSwap } from "@zaros/market-making/leaves/UsdTokenSwap.sol";
import { StabilityConfiguration } from "@zaros/market-making/leaves/StabilityConfiguration.sol";
import { EngineAccessControl } from "@zaros/utils/EngineAccessControl.sol";

// Open Zeppelin dependencies
import { IERC20, SafeERC20 } from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

contract StabilityBranch is EngineAccessControl {
    using Collateral for Collateral.Data;
    using MarketMakingEngineConfiguration for MarketMakingEngineConfiguration.Data;
    using SafeERC20 for IERC20;
    using SafeCast for uint256;
    using SafeCast for uint120;
    using StabilityConfiguration for StabilityConfiguration.Data;
    using UsdTokenSwap for UsdTokenSwap.Data;

    /// @notice Emitted to trigger the Chainlink Log based upkeep
    event LogInitiateSwap(
        address indexed caller,
        uint128 indexed requestId,
        uint128 vaultId,
        uint128 amountIn,
        uint128 minAmountOut,
        address assetOut,
        uint120 deadline
    );

    /// @notice Emitted when a swap is not fulfilled by the keeper and assets are refunded
    event LogRefundSwap(
        address indexed user,
        uint128 indexed requestId,
        uint128 vaultId,
        uint128 amountIn,
        uint128 minAmountOut,
        address assetOut,
        uint120 deadline,
        uint256 refundAmount
    );

    /// @notice Emitted when a swap is fulfilled by the keeper
    event LogFulfillSwap(
        address indexed user,
        uint128 indexed requestId,
        uint128 vaultId,
        uint128 amountIn,
        uint128 minAmountOut,
        address assetOut,
        uint120 deadline,
        uint256 amountOut
    );

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

    /// @notice Calculates the amount of assets to be received in a swap based on the input USD amount and its price.
    /// @param usdAmountInX18 The amount of USD tokens to be swapped in 18-decimal fixed-point format (UD60x18).
    /// @param priceX18 The price of the collateral asset in 18-decimal fixed-point format (UD60x18).
    /// @return amountOut The amount of assets to be received using in the ERC20's decimals, calculated from the input
    /// USD amount and its price.
    function getAmountOfAssetOut(
        UD60x18 usdAmountInX18,
        address asset,
        UD60x18 priceX18
    )
        public
        pure
        returns (uint256 amountOut)
    {
        // uint256 -> UD60x18
        UD60x18 usdAmountInX18 = ud60x18(usdAmountIn);

        // TODO: apply premium / discount
        // get amounts out taking into consideration CL price
        UD60x18 amountOutBeforeFeeX18 = usdAmountInX18.div(priceX18);

        // get the base and swap fee values in 18 decimals
        (UD60x18 baseFeeX18, UD60x18 swapFeeX18) = getFeesForAssetsAmountOut(amountOutBeforeFeeX18);

        // loads the asset's collateral config pointer
        Collateral.Data storage collateral = Collateral.load(asset);

        // subtract the fees and convert the UD60x18 value to the collateral's decimals value
        amountOut =
            collateral.convertUd60x18ToTokenAmount(amountOutBeforeFee.sub(baseFeeX18.add(swapFeeX18))).intoUint256();
    }

    /// @notice Returns the applicable fees for the specified amount of assets being paid in a swap.
    /// @param assetsAmountOutX18 The desired amount of assets to be acquired.
    /// @param priceX18 The current price of the asset in UD60x18 format.
    /// @return baseFeeX18 The base swap fee in assets units in UD60x18 format.
    /// @return swapFeeX18 The dynamic swap fee in assets units in UD60x18 format.
    function getFeesForAssetsAmountOut(
        UD60x18 assetsAmountOutX18,
        UD60x18 priceX18
    )
        public
        returns (UD60x18 baseFeeX18, UD60x18 swapFeeX18)
    {
        // load swap data
        UsdTokenSwap.Data storage tokenSwapData = UsdTokenSwap.load();

        // convert the base fee in usd to the asset amount to be charged
        baseFeeX18 = ud60x18(tokenSwapData.baseFeeUsd).div(priceX18);

        // calculates the swap fee portion rounding up
        swapFeeX18 = Math.divUp(
            assetsAmountOutX18.mul(ud60x18(tokenSwapData.swapSettlementFeeBps)), Constants.BPS_DENOMINATOR_X18
        );

        // load the mm engine configuration pointer
        // MarketMakingEngineConfiguration.Data storage marketMakingEngineConfiguration =
        //     MarketMakingEngineConfiguration.load();

        // calculates the protocol's share of the swap fee by multiplying the total swap fee by the protocol's fee
        // recipients' share.
        // uint256 protocolSwapFee =
        //     (ud60x18(totalSwapFee).mul(marketMakingEngineConfiguration.getTotalFeeRecipientsShares()).intoUint256());
        // // the protocol reward amount is the sum of the base fee and the protocol's share of the swap fee
        // uint256 protocolRewardAmount = baseFee + protocolSwapFee;
    }

    /// @notice Applies the swap fee to the USD token amount in the context of a refund.
    /// @dev The base and swap fees are only applied to the usd token amount in when the user requests a refund,
    /// otherwise, fees will be collected from the assets being paid out.
    /// @param usdAmountInX18 The original amount of USD tokens to be swapped, before the fee is deducted, in UD60x18.
    /// @return baseFeeUsdX18 The base fee charged from the usd token amount in UD60x18.
    /// @return swapFeeUsdX18 The dynamic swap fee charged from the usd token amount in UD60x18.
    function getFeesForUsdTokenAmountIn(UD60x18 usdAmountInX18)
        public
        returns (UD60x18 baseFeeUsdX18, UD60x18 swapFeeUsdX18)
    {
        // load swap data
        UsdTokenSwap.Data storage tokenSwapData = UsdTokenSwap.load();

        // returns the base fee in UD60x18
        baseFeeUsdX18 = ud60x18(tokenSwapData.baseFeeUsd);
        // calculates and returns the swap fee in UD60x18
        swapFeeUsdX18 =
            Math.divUp(usdAmountInX18.mul(ud60x18(tokenSwapData.swapSettlementFeeBps)), Constants.BPS_DENOMINATOR_X18);
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
        uint128[] calldata amountsIn,
        uint128[] calldata minAmountsOut
    )
        external
    {
        // Perform length checks
        if (vaultIds.length != amountsIn.length) {
            revert Errors.ArrayLengthMismatch(vaultIds.length, amountsIn.length);
        }

        if (amountsIn.length != minAmountsOut.length) {
            revert Errors.ArrayLengthMismatch(amountsIn.length, minAmountsOut.length);
        }

        // Load the first vault to store the initial collateral asset for comparison
        Vault.Data storage initialVault = Vault.load(vaultIds[0]);

        // cache the collateral asset's address
        address initialVaultCollateralAsset = initialVault.collateral.asset;

        // load collateral data
        Collateral.Data storage collateral = Collateral.load(initialVaultCollateralAsset);

        // Ensure the collateral asset is enabled
        collateral.verifyIsEnabled();

        // load market making engine config
        MarketMakingEngineConfiguration.Data storage configuration = MarketMakingEngineConfiguration.load();

        // load usd token swap data
        UsdTokenSwap.Data storage tokenSwapData = UsdTokenSwap.load();

        for (uint256 i; i < amountsIn.length; i++) {
            // if trying to create a swap request with a different collateral asset, we must revert
            if (Vault.load(vaultsIds[i]).collateral.asset != initialVaultCollateralAsset) {
                revert Errors.VaultsCollateralAssetsMismatch();
            }

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
            swapRequest.assetOut = initialVaultCollateralAsset;
            swapRequest.deadline = uint120(block.timestamp) + uint120(tokenSwapData.maxExecutionTime);
            swapRequest.amountIn = amountsIn[i];

            emit LogInitiateSwap(
                msg.sender,
                requestId,
                vaultIds[i],
                amountsIn[i],
                minAmountsOut[i],
                swapRequest.assetOut,
                swapRequest.deadline
            );
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
        onlyRegisteredSystemKeepers
    {
        // load request for user by id
        UsdTokenSwap.SwapRequest storage request = UsdTokenSwap.load().swapRequests[user][requestId];

        // revert if already processed
        if (request.processed) {
            revert Errors.RequestAlreadyProcessed(user, requestId);
        }

        // if request dealine expired revert
        if (request.deadline < block.timestamp) {
            revert Errors.SwapRequestExpired(user, requestId, request.deadline);
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
        StabilityConfiguration.Data storage stabilityConfiguration = StabilityConfiguration.load();

        // get price from report in 18 dec
        UD60x18 priceX18 = stabilityConfiguration.verifyOffchainPrice(priceData);

        // get amount out asset
        uint256 amountOut = getAmountOfAssetOut(request.amountIn, priceX18);

        // deduct fee
        uint256 amountOutAfterFee = _handleFeeAsset(amountOut, vault.collateral.asset, priceX18);

        // slippage check
        if (amountOutAfterFee < request.minAmountOut) {
            revert Errors.SlippageCheckFailed(request.minAmountOut, amountOutAfterFee);
        }

        // burn usd amount from address(this)
        usdToken.burn(request.amountIn);

        // update vault debt
        vault.unsettledRealizedDebtUsd -= int128(request.amountIn);

        // vault => user
        IERC20(vault.collateral.asset).safeTransferFrom(address(vault.indexToken), user, amountOutAfterFee);

        emit LogFulfillSwap(
            user,
            requestId,
            request.vaultId,
            request.amountIn,
            request.minAmountOut,
            request.assetOut,
            request.deadline,
            amountOutAfterFee
        );
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
        (uint256 refundAmount, uint256 feeAmount) = _handleFeeUsd(request.amountIn);

        // transfer fee too fee recipient
        IERC20(usdToken).safeTransfer(address(1), feeAmount); // TODO: set USD token fee recipien

        // transfer usd refund amount back to user
        IERC20(usdToken).safeTransfer(msg.sender, refundAmount);

        emit LogRefundSwap(
            msg.sender,
            requestId,
            request.vaultId,
            request.amountIn,
            request.minAmountOut,
            request.assetOut,
            request.deadline,
            refundAmount
        );
    }

    // /// @notice Applies the swap fee to the USD token amount and either mints or transfers the fee to the fee
    // /// recipient.
    // /// @param amountIn The original amount of USD tokens to be swapped, before the fee is deducted.
    // /// @return The amount of USD tokens remaining after the fee is deducted and the fee
    // function _handleFeeUsd(uint256 amountIn) internal view returns (uint256, uint256) {
    //     // load swap data
    //     UsdTokenSwap.Data storage tokenSwapData = UsdTokenSwap.load();

    //     // Calculate the total fee
    //     uint256 feeAmount = tokenSwapData.baseFeeUsd + (amountIn * tokenSwapData.swapSettlementFeeBps) / 10_000;

    //     // deduct the fee from the amountIn
    //     amountIn -= feeAmount;

    //     // return amountIn after fee was applied
    //     return (amountIn, feeAmount);
    // }

    // /// @notice Calculates and deducts the applicable fee from the specified asset amount.
    // /// @param amountOut The initial amount of the asset being processed.
    // /// @param asset The address of the asset for which the fee is being calculated.
    // /// @param priceX18 The current price of the asset in UD60x18 format.
    // /// @return The amount remaining after the base and settlement fees have been deducted.
    // // todo: refactor this function in two steps, view and non-view, to return the expected amount out to external
    // // clients taking fees into account.
    // function _handleFeeAsset(uint256 assetsAmountOut, address asset, UD60x18 priceX18) internal returns (uint256) {
    //     // load swap data
    //     UsdTokenSwap.Data storage tokenSwapData = UsdTokenSwap.load();

    //     // load collateral data
    //     Collateral.Data storage collateral = Collateral.load(asset);

    //     // convert the base fee in usd to the asset amount to be charged
    //     UD60x18 baseFeeX18 = ud60x18(tokenSwapData.baseFeeUsd).div(priceX18);

    //     // UD60x18 -> uint256
    //     uint256 baseFee = collateral.convertUd60x18ToTokenAmount(baseFeeX18);
    //     // calculates the swap fee portion
    //     // TODO: come back here and see if we work with bps using 18 decimals or not
    //     uint256 totalSwapFee = assetsAmountOut * tokenSwapData.swapSettlementFeeBps / Constants.BPS_DENOMINATOR;

    //     // load the mm engine configuration pointer
    //     MarketMakingEngineConfiguration.Data storage marketMakingEngineConfiguration =
    //         MarketMakingEngineConfiguration.load();

    //     // calculates the protocol's share of the swap fee by multiplying the total swap fee by the protocol's fee
    //     // recipients' share.
    //     uint256 protocolSwapFee =
    //         (ud60x18(totalSwapFee).mul(marketMakingEngineConfiguration.getTotalFeeRecipientsShares()).intoUint256());
    //     // the protocol reward amount is the sum of the base fee and the protocol's share of the swap fee
    //     uint256 protocolRewardAmount = baseFee + protocolSwapFee;

    //     // todo: distribute fee straight to the vault's weth reward distribution? or store it somewhere else?
    //     // todo: distribute swapFee - protocolSwapFee to vaults

    //     // distributes the protocol reward paid in the asset
    //     marketMakingEngineConfiguration.distributeProtocolAssetReward(asset, protocolRewardAmount);

    //     // deduct the fee from the amount in
    //     assetsAmountOut -= baseFee + totalSwapFee;

    //     // return amountIn after fee was applied
    //     return assetsAmountOut;
    // }
}
