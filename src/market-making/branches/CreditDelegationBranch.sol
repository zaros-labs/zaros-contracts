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
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, ZERO as SD59x18_ZERO, unary } from "@prb-math/SD59x18.sol";

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

    /// @notice Emitted when the market making engine receives margin collateral from an engine.
    /// @param engine The address of the engine that called the function.
    /// @param marketId The engine's market id.
    /// @param collateralType The margin collateral address.
    /// @param amount The token amount of collateral received.
    event LogDepositCreditForMarket(
        address indexed engine, uint128 indexed marketId, address collateralType, uint256 amount
    );

    /// @notice Emitted when the perps engine requests USDz to be minted by the market making engine.
    /// @param engine The address of the engine that called the function.
    /// @param marketId The engine's market id.
    /// @param requestedUsdzAmount The requested amount of USDz to minted.
    /// @param mintedUsdzAmount The actual amount of USDz minted, potentially factored by the market's auto deleverage
    /// system.
    event LogRequestUsdzForMarket(
        address indexed engine, uint128 indexed marketId, uint256 requestedUsdzAmount, uint256 mintedUsdzAmount
    );

    // TODO: check if `msg.sender` is registered
    modifier onlyRegisteredEngine() {
        // load market making engine configuration and the perps engine address
        MarketMakingEngineConfiguration.Data storage marketMakingEngineConfiguration =
            MarketMakingEngineConfiguration.load();

        // if `msg.sender` is not a registered engine, revert
        if (!marketMakingEngineConfiguration.registeredEngines[msg.sender]) {
            revert Errors.Unauthorized(msg.sender);
        }

        // continue execution
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Returns the credit delegation state of the given market id.
    /// @dev `CreditDelegationBranch::updateCreditDelegation` must be called before calling this function in order to
    /// retrieve the latest state.
    /// @dev Each engine can implement its own credit schema according to its business logic, thus, this function will
    /// return the credit delegation state as an abi encoded byte array.
    /// @param marketId The engine's market id.
    /// @return creditCapacityUsdX18 The current credit capacity of the given market id in USD.
    function getCreditCapacityForMarketId(uint128 marketId) public view returns (SD59x18 creditCapacityUsdX18) {
        MarketDebt.Data storage marketDebt = MarketDebt.load(marketId);

        return marketDebt.getCreditCapacity(marketDebt.getDelegatedCredit());
    }

    /// @notice Returns the adjusted profit of an active position at the given market id, considering the market's ADL
    /// state.
    /// @dev If the market is in its default state, it will simply return the provided profit. Otherwise, it will
    /// adjust based on the configured ADL parameters.
    /// @param marketId The engine's market id.
    /// @param profitUsd The position's profit in USD.
    /// @return adjustedProfitUsdX18 The adjusted profit in USDz, according to the market's state.
    // TODO: add invariants
    function getAdjustedProfitForMarketId(
        uint128 marketId,
        uint256 profitUsd
    )
        public
        view
        returns (UD60x18 adjustedProfitUsdX18)
    {
        // load the market's debt data storage pointer
        MarketDebt.Data storage marketDebt = MarketDebt.load(marketId);
        // cache the market's total debt
        SD59x18 marketTotalDebtUsdX18 = marketDebt.getTotalDebt();
        // uint256 -> UD60x18
        UD60x18 profitUsdX18 = ud60x18(profitUsd);

        SD59x18 creditCapacityUsdX18 = marketDebt.getCreditCapacity(marketDebt.getDelegatedCredit());

        // TODO: is this check needed?
        if (creditCapacityUsdX18.lte(SD59x18_ZERO)) revert Errors.InsufficientCreditCapacity(marketId, profitUsd);

        // we don't need to add `profitUsd` as it's assumed to be part of the total debt
        // NOTE: If this if doesn't stop execution, we assume marketTotalDebtUsdX18 is positive
        if (!marketDebt.isAutoDeleverageTriggered(marketTotalDebtUsdX18)) {
            // if the market is not in the ADL state, it returns the profit as is
            adjustedProfitUsdX18 = profitUsdX18;
            return adjustedProfitUsdX18;
        }

        adjustedProfitUsdX18 = marketDebt.getAutoDeleverageFactor(
            creditCapacityUsdX18.intoUD60x18(), marketTotalDebtUsdX18.intoUD60x18()
        ).mul(profitUsdX18);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                  PERPS ENGINE ONLY PROTECTED FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/
    /// @notice Adds credit in form of a registered collateral type to the given market id.
    /// @dev Engines call this function to send collateral collected from their users and increase their credit
    /// capacity, rewarding the market making engine's LPs.
    /// @dev Called by the perps engine to send margin collateral deducted from a trader's account during a negative
    /// pnl settlement or a liquidation event.
    /// @dev The system must enforce that if a market is running by an engine, it must have some delegated credit. In
    /// order to delist a market and allow Vaults to fully undelegate the provided credit, it first must be disabled
    /// at the engine level in order to prevent users from being able to fulfill their expected profits.
    /// @param marketId The engine's market id.
    /// @param collateralType The margin collateral address.
    /// @param amount The token amount of collateral to receive.
    /// @dev Invariants involved in the call:
    ///     * marketDebt.getDelegatedCredit() > 0
    ///     * ERC20(collateralType).allowance(perpsEngine, marketMakingEngine) >= amount
    ///     * ERC20(collateralType).balanceOf(perpsEngine) >= amount
    ///     * marketDebt.collectedMarginCollateral.get(collateralType) ==  ∑convertTokenAmountToUd60x18(amount)
    ///     * ERC20(collateralType).balanceOf(marketMakingEngine) == ∑amount
    function depositCreditForMarket(
        uint128 marketId,
        address collateralType,
        uint256 amount
    )
        external
        onlyRegisteredEngine
    {
        if (amount == 0) revert Errors.ZeroInput("amount");
        // loads the collateral's data storage pointer
        Collateral.Data storage collateral = Collateral.load(collateralType);

        // reverts if collateral isn't supported
        collateral.verifyIsEnabled();

        // loads the market's debt data storage pointer
        MarketDebt.Data storage marketDebt = MarketDebt.load(marketId);

        // enforces that the market has enough credit capacity, if it' a listed market it must always have some
        // delegated credit, see Vault.Data.lockedCreditRatio.
        // NOTE: additionally, the ADL system if functioning properly must ensure that the market always has credit
        // capacity to cover USDz mint requests. Deleverage happens when the perps engine calls
        // CreditDelegationBranch::getAdjustedProfitForMarketId
        if (marketDebt.getDelegatedCredit().isZero()) {
            revert Errors.NoDelegatedCredit(marketId);
        }

        // uint256 -> UD60x18 and scale decimals to 18
        UD60x18 amountX18 = collateral.convertTokenAmountToUd60x18(amount);

        // adds the collected margin collateral to the market's debt data storage, to be settled later
        marketDebt.addMarginCollateral(collateralType, amount);

        // calculates the usd value of margin collateral received
        UD60x18 receivedValueUsdX18 = collateral.getPrice().mul(amountX18);

        // realizes the received margin collateral usd value as added credit
        marketDebt.realizeDebt(unary(receivedValueUsdX18.intoSD59x18()));

        // transfers the margin collateral asset from the perps engine to the market making engine
        // NOTE: The engine must approve the market making engine to transfer the margin collateral asset, see
        // PerpsEngineConfigurationBranch::setMarketMakingEngineAllowance
        IERC20(collateralType).safeTransferFrom(msg.sender, address(this), amount);

        // emit an event
        emit LogDepositCreditForMarket(msg.sender, marketId, collateralType, amount);
    }

    /// @notice Mints the requested amount of USDz to the caller and updates the market's
    /// debt state.
    /// @dev Called by a registered engine to mint USDz to profitable traders.
    /// @dev USDz association with a trading account happens at the engine level.
    /// @dev This function assumes the perps engine won't call it with a zero amount.
    /// @dev Effects must be performed at the perps engine beforehand, otherwise this function will assume an invalid
    /// total debt value.
    /// @param marketId The engine's market id requesting USDz.
    /// @param amount The amount of USDz to mint.
    /// @dev Invariants involved in the call:
    /// TODO: add invariants
    function requestUsdzForMarket(uint128 marketId, uint256 amount) external onlyRegisteredEngine {
        // loads the market's debt data storage pointer
        MarketDebt.Data storage marketDebt = MarketDebt.load(marketId);

        // we need to first recalculate the latest credit delegation state
        marketDebt.recalculateDelegatedCredit();

        // uint256 -> UD60x18
        // NOTE: we don't need to scale decimals here as it's known that USDz has 18 decimals
        UD60x18 amountX18 = ud60x18(amount);
        // cache the market's delegated credit
        UD60x18 delegatedCreditUsdX18 = marketDebt.getDelegatedCredit();

        // enforces that the market has enough credit capacity, if it' a listed market it must always have some
        // delegated credit, see Vault.Data.lockedCreditRatio.
        // NOTE: additionally, the ADL system if functioning properly must ensure that the market always has credit
        // capacity to cover USDz mint requests. Deleverage happens when the perps engine calls
        // CreditDelegationBranch::getAdjustedProfitForMarketId
        if (marketDebt.getCreditCapacity(delegatedCreditUsdX18).lt(amountX18.intoSD59x18())) {
            revert Errors.InsufficientCreditCapacity(marketId, amountX18.intoUint256());
        }

        // prepare the amount of usdz that will be minted to the perps engine
        uint256 amountToMint;
        // cache the market's total debt
        SD59x18 marketTotalDebtUsdX18 = marketDebt.getTotalDebt();

        // now we realize the added usd debt of the market
        // note: USDz is assumed to be 1:1 with the system's usd accounting
        if (marketDebt.isAutoDeleverageTriggered(marketTotalDebtUsdX18.add(amountX18.intoSD59x18()))) {
            // if the market is in the ADL state, it reduces the requested USDz amount by multiplying it by the ADL
            // factor, which must be < 1
            UD60x18 adjustedUsdzToMintX18 = marketDebt.getAutoDeleverageFactor(
                marketDebt.getCreditCapacity(delegatedCreditUsdX18).intoUD60x18(), marketTotalDebtUsdX18.intoUD60x18()
            ).mul(amountX18);
            amountToMint = adjustedUsdzToMintX18.intoUint256();
            marketDebt.realizeDebt(adjustedUsdzToMintX18.intoSD59x18());
        } else {
            // if the market is not in the ADL state, it realizes the full requested USDz amount
            amountToMint = amountX18.intoUint256();
            marketDebt.realizeDebt(amountX18.intoSD59x18());
        }

        // loads the market making engine configuration storage pointer
        MarketMakingEngineConfiguration.Data storage marketMakingEngineConfiguration =
            MarketMakingEngineConfiguration.load();
        // cache the USDz address
        USDToken usdz = USDToken(marketMakingEngineConfiguration.usdz);

        // mints USDz to the perps engine
        usdz.mint(msg.sender, amountToMint);

        // emit an event
        emit LogRequestUsdzForMarket(msg.sender, marketId, amount, amountToMint);
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
    // TODO: update credit delegation and debt distribution chain
    // TODO: how to account for collected margin collateral's fluctuation in value?
    function updateCreditDelegation() public { }

    /// @dev Called by the perps trading engine to update the credit delegation and return the credit for a given
    /// market id
    /// @dev Invariants involved in the call:
    /// @param marketId The engine's market id.
    /// @return creditCapacityUsdX18 The current credit capacity of the given market id in USD.
    /// TODO: add invariants
    function updateCreditDelegationAndReturnCreditForMarketId(uint128 marketId)
        external
        returns (SD59x18 creditCapacityUsdX18)
    {
        updateCreditDelegation();
        return getCreditCapacityForMarketId(marketId);
    }
}
