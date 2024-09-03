// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { USDToken } from "@zaros/usd/USDToken.sol";
// import { CreditDelegation } from "@zaros/market-making/leaves/CreditDelegation.sol";
import { Collateral } from "@zaros/market-making/leaves/Collateral.sol";
import { MarketDebt } from "@zaros/market-making/leaves/MarketDebt.sol";
import { MarketMakingEngineConfiguration } from "@zaros/market-making/leaves/MarketMakingEngineConfiguration.sol";
import { SystemDebt } from "@zaros/market-making/leaves/SystemDebt.sol";
import { Vault } from "@zaros/market-making/leaves/Vault.sol";

// Open Zeppelin dependencies
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";
import { IERC20, SafeERC20 } from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, ZERO as SD59x18_ZERO } from "@prb-math/SD59x18.sol";

/// @dev This contract deals with USDC to settle protocol debt, used to back USDz
contract CreditDelegationBranch {
    using Collateral for Collateral.Data;
    using MarketDebt for MarketDebt.Data;
    using MarketMakingEngineConfiguration for MarketMakingEngineConfiguration.Data;
    using SafeCast for uint256;
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////////////////
                                  EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the market making engine receives margin collateral from the perps engine.
    /// @param marketId The perps engine's market id.
    /// @param collateralType The margin collateral address.
    /// @param amount The token amount of collateral received.
    event LogReceiveMarginCollateral(uint128 indexed marketId, address collateralType, uint256 amount);

    /// @notice Emitted when the perps engine requests USDz to be minted by the market making engine.
    /// @param marketId The perps engine's market id.
    /// @param amount The amount of USDz to mint.
    event LogRequestUsdzForMarketId(uint128 indexed marketId, uint256 amount);

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
    /// @dev This function assumes the perps engine won't call it with a zero amount.
    /// @param collateralType The margin collateral address.
    /// @param amount The token amount of collateral to receive.
    /// @dev Invariants involved in the call:
    ///     * marketDebt.getDelegatedCredit() > 0
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

        if (marketDebt.getCreditCapacity().lt(SD59x18_ZERO)) {
            revert Errors.NoCreditCapacity(marketId);
        }

        // adds the collected margin collateral to the market's debt data storage, to be settled later
        marketDebt.addMarginCollateral(collateralType, amount);

        // transfers the margin collateral asset from the perps engine to the market making engine
        // NOTE: The perps engine must approve the market making engine to transfer the margin collateral asset, see
        // PerpsEngineConfigurationBranch::setMarketMakingEngineAllowance
        IERC20(collateralType).safeTransferFrom(msg.sender, address(this), amount);

        // emit an event
        emit LogReceiveMarginCollateral(marketId, collateralType, amount);
    }

    /// @notice Mints the requested amount of USDz to the perps engine and updates the market's debt state.
    /// @dev Called by the perps engine to mint USDz to profitable traders.
    /// @dev USDz association with a trading account happens at the perps engine.
    /// @dev This function assumes the perps engine won't call it with a zero amount.
    /// @dev Effects must be applied at the perps engine before calling this function, otherwise it will assume an
    /// incorrect total debt value.
    /// @param marketId The perps engine's market id requesting USDz.
    /// @param amount The amount of USDz to mint.
    /// @dev Invariants involved in the call:
    /// TODO: add invariants
    function requestUsdzForMarketId(uint128 marketId, uint256 amount) external onlyPerpsEngine {
        // loads the market's debt data storage pointer
        MarketDebt.Data storage marketDebt = MarketDebt.load(marketId);

        // get the vault ids delegating credit to this market
        uint256[] memory connectedVaultsIds = marketDebt.getConnectedVaultsIds();

        // if the market has delegated credit, this scenario should never happen, but we double check and consider
        // it a panic state
        if (connectedVaultsIds.length == 0) {
            revert Errors.NoConnectedVaults(marketId);
        }

        // enforces that the market has delegated credit, if it' a listed market it must always have delegated credit,
        // see Vault.Data.lockedCreditRatio
        if (marketDebt.getDelegatedCredit().isZero()) {
            revert Errors.NoDelegatedCredit(marketId);
        }

        // update the market's vaults debt distribution and its realized debt, returning the unsettled debt change
        SD59x18 unsettledDebtChangeUsdX18 =
            marketDebt.distributeDebtToVaults(marketDebt.getTotalDebt(), sd59x18(amount.toInt256()));

        // updates the unsettled debt values of each vault delegating credit to this market, according to the realized
        // debt change of this market
        Vault.updateVaultsUnsettledDebt(connectedVaultsIds, unsettledDebtChangeUsdX18);

        // loads the market making engine configuration storage pointer
        MarketMakingEngineConfiguration.Data storage marketMakingEngineConfiguration =
            MarketMakingEngineConfiguration.load();
        // cache the USDz address
        USDToken usdz = USDToken(marketMakingEngineConfiguration.usdz);

        // mints USDz to the perps engine
        usdz.mint(msg.sender, amount);

        // emit an event
        // TODO: add parameters
        emit LogRequestUsdzForMarketId(marketId, amount);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   UNPROTECTED FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Converts ZLP Vaults unsettled debt to settled debt by:
    ///     - Swapping the balance of collected margin collateral to USDC, if available.
    ///     - Swapping the ZLP Vaults assets to USDC, according to the state of
    /// `SystemDebt.vaultsDebtSettlementPriorityQueue`.
    /// @dev USDC acquired from onchain markets is stored and used to cover future USDz swaps.
    /// @dev The Settlement Priority Queue is stored as a MinHeap, ordering vaults with the highest debt first.
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
