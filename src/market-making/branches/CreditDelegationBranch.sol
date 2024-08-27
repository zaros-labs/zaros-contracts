// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
// import { CreditDelegation } from "@zaros/market-making/leaves/CreditDelegation.sol";
import { Collateral } from "@zaros/market-making/leaves/Collateral.sol";
import { MarketDebt } from "@zaros/market-making/leaves/MarketDebt.sol";
import { MarketMakingEngineConfiguration } from "@zaros/market-making/leaves/MarketMakingEngineConfiguration.sol";
import { SystemDebt } from "@zaros/market-making/leaves/SystemDebt.sol";
import { Vault } from "@zaros/market-making/leaves/Vault.sol";

// Open Zeppelin dependencies
import { IERC20, SafeERC20 } from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";

// PRB Math dependencies
import { UD60x18, SD59x18 } from "@prb-math/UD60x18.sol";

/// @dev This contract deals with USDC to settle protocol debt, used to back USDz
contract CreditDelegationBranch {
    using Collateral for Collateral.Data;
    using MarketDebt for MarketDebt.Data;
    using MarketMakingEngineConfiguration for MarketMakingEngineConfiguration.Data;
    using SafeERC20 for IERC20;

    modifier onlyPerpsEngine() {
        // load market making engine configuration and the perps engine address
        MarketMakingEngineConfiguration.Data storage marketMakingEngineConfiguration =
            MarketMakingEngineConfiguration.load();
        address perpsEngine = marketMakingEngineConfiguration.perpsEngine;

        if (msg.sender != perpsEngine) {
            revert Errors.Unauthorized(msg.sender);
        }

        // continue execution
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Returns the OI and skew caps for the given market id.
    /// @dev `CreditDelegationBranch::updateCreditDelegation` must be called before calling this function in order to
    /// retrieve the latest state.
    /// @param marketId The perps engine's market id.
    /// @return openInterestCapX18 The market's open interest cap.
    /// @return skewCapX18 The market's skew cap.
    function getCreditForMarketId(uint128 marketId)
        public
        view
        returns (UD60x18 openInterestCapX18, UD60x18 skewCapX18)
    {
        MarketDebt.Data storage marketDebt = MarketDebt.load(marketId);

        (openInterestCapX18, skewCapX18) = marketDebt.getMarketCaps();
    }

    /// @notice Returns the adjusted pnl of an active position at the given market id, considering the market's ADL
    /// state.
    /// @dev If the market is in its default state, it will simply return the provided pnl. Otherwise, it will adjust
    /// based on the configured ADL parameters and state.
    /// @param marketId The perps engine's market id.
    /// @param pnl The position's pnl.
    /// @return adjustedPnlX18 The adjusted pnl, according to the market state.
    function getAdjustedPnlForMarketId(uint128 marketId, int256 pnl) public view returns (SD59x18 adjustedPnlX18) { }

    /*//////////////////////////////////////////////////////////////////////////
                                  PERPS ENGINE ONLY PROTECTED FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/
    /// @notice Receives margin collateral from a trader's account.
    /// @dev Called by the perps engine to send margin collateral deducted from a trader's account during a negative
    /// pnl settlement or a liquidation event.
    /// @dev The system must enforce that if a market is live in the perps engine, it must have delegated credit. In
    /// order to delist a market and allow withdrawing all delegated credit, it first must be disabled at the perps
    /// engine.
    /// @param collateralType The margin collateral address.
    /// @param amount The token amount of collateral to receive.
    /// @dev Invariants involved in the call:
    ///      * marketDebt.getDelegatedCredit() > 0
    ///     * ERC20(collateralType).allowance(perpsEngine, marketMakingEngine) >= amount
    ///     * ERC20(collateralType).balanceOf(perpsEngine) >= amount
    ///     * marketDebt.collectedMarginCollateral.get(collateralType) ==  ∑convertTokenAmountToUd60x18(amount)
    ///     * ERC20(collateralType).balanceOf(marketMakingEngine) == ∑amount
    function receiveMarginCollateral(
        uint128 marketId,
        address collateralType,
        uint256 amount
    )
        external
        onlyPerpsEngine
    {
        // loads the collateral's data storage pointer
        Collateral.Data storage collateral = Collateral.load(collateralType);

        // reverts if collateral isn't supported
        collateral.verifyIsEnabled();

        // loads the market's debt data storage pointer
        MarketDebt.Data storage marketDebt = MarketDebt.load(marketId);

        // enforces that the market has delegated credit, if it' a listed market it must always have delegated credit,
        // see Vault.lockedCreditRatio
        if (marketDebt.getDelegatedCredit().isZero()) {
            revert Errors.NoDelegatedCredit(marketId);
        }

        // scale the provided amount's decimals if needed and convert it to UD60x18
        UD60x18 amountX18 = collateral.convertTokenAmountToUd60x18(amount);

        // adds the collected margin collateral to the market's debt data storage, to be settled later
        marketDebt.addMarginCollateral(collateralType, amountX18);

        // transfers the margin collateral asset from the perps engine to the market making engine
        // NOTE: The perps engine must approve the market making engine to transfer the margin collateral asset, see
        // PerpsEngineConfigurationBranch::setMarketMakingEngineAllowance
        IERC20(collateralType).safeTransferFrom(msg.sender, address(this), amount);
    }

    /// @notice Mints the requested amount of USDz to the perps engine and updates the market's debt state.
    /// @dev Called by the perps engine to mint USDz to profitable traders.
    /// @dev Association with a trading account happens at the perps engine.
    /// @param marketId The perps engine's market id requesting USDz.
    /// @param amount The amount of USDz to mint.
    /// @dev Invariants involved in the call:
    /// TODO: add invariants
    function requestUsdzForMarketId(uint128 marketId, uint256 amount) external onlyPerpsEngine { }

    /*//////////////////////////////////////////////////////////////////////////
                                   UNPROTECTED FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Should settle vault's unsettled debt by converting the balance of different margin collateral types to
    /// USDC, stored and used to cover future USDz swaps, and settle credit by converting the collected margin
    /// collateral balance to the vaults' underlying assets.
    /// @dev Settlement Priority:
    /// 1. highest to lowest debt.
    /// 2. highest to lowest credit.
    /// @dev The protocol should also take into account the system debt state. E.g: if the protocol is in credit state
    /// but a given vault is in net debt due to swaps, other vaults' exceeding credit (i.e exceeding assets) can be
    /// converted to the in debt vault's underlying assets. If the protocol is in debt state but there's a vault with
    /// net credit due to swaps, the protocol can rebalance other vaults by distributing exceeding assets from that
    /// vault.
    /// @dev In order to determine the logic above, it should be taken into account a vault's participation in the
    /// system debt or credit. E.g if the protocol is in a given state and a new ZLP vault is added, this new vault is
    /// neutral compared to the others that may be in credit or debt state.
    /// @dev Invariants involved in the call:
    /// TODO: add invariants
    function settleVaultsDebt() external { }

    /// @dev Must be called whenever the perps trading engine needs to know a market's skew and OI caps.
    /// @dev It takes into accounts all vault's credit delegated to each supported market. `n` Vaults may delegate
    /// credit to `n` markets, configured by the protocol admin.
    /// @dev Invariants involved in the call:
    /// TODO: add invariants
    function updateCreditDelegation() public { }

    /// @dev Called by the perps trading engine to update the credit delegation and return the credit for a given
    /// market id
    /// @dev Invariants involved in the call:
    /// @param marketId The perps engine's market id.
    /// @return openInterestCapX18 The market's open interest cap.
    /// @return skewCapX18 The market's skew cap.
    /// TODO: add invariants
    function updateCreditDelegationAndReturnCreditForMarketId(uint128 marketId)
        external
        returns (UD60x18 openInterestCapX18, UD60x18 skewCapX18)
    {
        updateCreditDelegation();
        return getCreditForMarketId(marketId);
    }
}
