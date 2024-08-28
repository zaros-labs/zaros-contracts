// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Fee } from "../leaves/Fee.sol";
import { Collateral } from "../leaves/Collateral.sol";
import { FeeRecipient } from "../leaves/FeeRecipient.sol";
import { Vault } from "../leaves/Vault.sol";
import { MarketMakingEngineConfiguration } from "../leaves/MarketMakingEngineConfiguration.sol";
import { Errors } from "@zaros/utils/Errors.sol";

// PRB Math dependencies
import { UD60x18, ud60x18, ZERO as UD_ZERO } from "@prb-math/UD60x18.sol";

// Open Zeppelin dependencies
import { IERC20, IERC4626, SafeERC20 } from "@openzeppelin/token/ERC20/extensions/ERC4626.sol";

/// @dev This contract deals with ETH to settle accumulated protocol fees, distributed to LPs and stakeholders.
contract FeeDistributionBranch {
    using SafeERC20 for IERC20;
    using Fee for Fee.Data;
    using FeeRecipient for FeeRecipient.Data;
    using Collateral for Collateral.Data;
    using Vault for Vault.Data;
    using MarketMakingEngineConfiguration for MarketMakingEngineConfiguration.Data;

    modifier onlyAuthorized {
        if(msg.sender != MarketMakingEngineConfiguration.load().perpsEngine){
            revert Errors.Unauthorized(msg.sender);
        }
        _;
    }

    /// @notice Emit when order fee is received
    /// @param collateral the address of collateral type
    /// @param amount the received fee amount
    event OrderFeeReceived(address indexed collateral, uint256 amount);

    /// @notice Returns the claimable amount of WETH fees for the given staker at a given vault.
    /// @param vaultId The vault id to claim fees from.
    /// @param staker The staker address.
    /// @return The amount of WETH fees claimable.
    function getEarnedFees(uint128 vaultId, address staker) external view returns (uint256) { }

    /// @dev Invariants involved in the call:
    /// TODO: add invariants
    /// @param collateral The margin collateral address.
    /// @param amount The token amount of collateral to receive as fee.

    function receiveOrderFee(address collateral, uint256 amount) external onlyAuthorized {
        // fetch collateral asset address
        address collateralAssetAddress = Collateral.load(collateral).asset;

        // revert if collateral asset not supported
        if (collateralAssetAddress == address(0)) revert Errors.UnsupportedCollateralType();
    

        if (IERC20(collateral).balanceOf(msg.sender) < amount) revert Errors.NotEnoughCollateralBalance(IERC20(collateral).balanceOf(msg.sender));

        // fetch storage slot for fee data
        Fee.Data storage fee = Fee.load();

        // store in array if new collateral
        if (fee.feeAmounts[collateral] == 0) {
            fee.orderFeeCollaterals.push(collateral);
        }

        // increment fee amount
        fee.feeAmounts[collateral] += amount;

        // transfer fee amount
        IERC20(collateral).safeTransferFrom(msg.sender, address(this), amount);

        emit OrderFeeReceived(collateral, amount);
    }

    /// @dev Invariants involved in the call:
    /// TODO: add invariants
    function convertAccumulatedFeesToWeth() external onlyAuthorized {
        Fee.Data storage feeData = Fee.load();

        for (uint256 i = 0; i < feeData.orderFeeCollaterals.length; i++) {

            // TODO: Implement UNISWAP swap
    
            feeData.feeAmounts[feeData.orderFeeCollaterals[i]] = 0;
        }

        delete feeData.orderFeeCollaterals;

        uint256 feeDistributorShares = FeeRecipient.load(MarketMakingEngineConfiguration.load().feeDistributor).share;

        uint256 feeAmountToDistributor = _calculateFees(feeDistributorShares, feeData.accumulatedWeth, Fee.TOTAL_FEE_SHARES);

        feeData.feeDistributorUnsettled = feeAmountToDistributor;

        feeData.recipientsFeeUnsettled = feeData.accumulatedWeth - feeData.feeDistributorUnsettled;

        feeData.accumulatedWeth = 0;
    }

    /// @dev Invariants involved in the call:
    /// TODO: add invariants
    function sendWethToFeeDistributor() external onlyAuthorized {

        address feeDistributor = MarketMakingEngineConfiguration.load().feeDistributor;

        address wethAddr = MarketMakingEngineConfiguration.load().weth;

        Fee.Data storage feeData = Fee.load();
        uint256 amountToSend = feeData.feeDistributorUnsettled;
        feeData.feeDistributorUnsettled = 0;
        // send fee amount to feeDistributor
        IERC20(wethAddr).safeTransfer(feeDistributor, amountToSend);
    }

    /// @dev Invariants involved in the call:
    /// TODO: add invariants
    function sendWethToFeeRecipients(uint256 configuration) external {
        MarketMakingEngineConfiguration.Data storage marketMakingEngineConfigurationData =
            MarketMakingEngineConfiguration.load();


        if (msg.sender != marketMakingEngineConfigurationData.perpsEngine) {
            revert Errors.Unauthorized(msg.sender);
        }

        address[] storage recipientsList = marketMakingEngineConfigurationData.feeRecipients[configuration];
        address wethAddr = marketMakingEngineConfigurationData.weth;

        uint256 feeDistributorShares = FeeRecipient.load(marketMakingEngineConfigurationData.feeDistributor).share;
        uint256 totalShares = Fee.TOTAL_FEE_SHARES - feeDistributorShares;

        uint256 recipientsFeeUnsettled = Fee.load().recipientsFeeUnsettled;
        
        for (uint256 i; i < recipientsList.length; ++i) {
            FeeRecipient.Data storage feeRecipientData = FeeRecipient.load(recipientsList[i]);
            uint256 amountToSend = _calculateFees(feeRecipientData.share, recipientsFeeUnsettled, totalShares);

            address recipientAddress = recipientsList[i];

            IERC20(wethAddr).safeTransfer(recipientAddress, amountToSend);
        }
    }

    /// @dev Invariants involved in the call:
    /// TODO: add invariants
    /// @param vaultId The vault id to claim fees from.
    function claimFees(uint128 vaultId) external { }

    function _calculateFees(
        uint256 shares,
        uint256 accumulatedAmount,
        uint256 totalShares
    )
        internal
        view
        returns (uint256 amount)
    {
        amount = (shares * accumulatedAmount) / totalShares;
    }
}
