// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { UsdToken } from "@zaros/usd/UsdToken.sol";
import { Collateral } from "@zaros/market-making/leaves/Collateral.sol";
import { Market } from "@zaros/market-making/leaves/Market.sol";
import { MarketMakingEngineConfiguration } from "@zaros/market-making/leaves/MarketMakingEngineConfiguration.sol";
// import { SystemDebt } from "@zaros/market-making/leaves/SystemDebt.sol";
import { Vault } from "@zaros/market-making/leaves/Vault.sol";
import { EngineAccessControl } from "@zaros/utils/EngineAccessControl.sol";

// Open Zeppelin dependencies
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";
import { IERC20, SafeERC20 } from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, ZERO as SD59x18_ZERO, unary } from "@prb-math/SD59x18.sol";

/// @dev This contract deals with USDC to settle protocol debt, used to back USD Token
contract CreditDelegationBranch {
    using Collateral for Collateral.Data;
    using Market for Market.Data;
    using MarketMakingEngineConfiguration for MarketMakingEngineConfiguration.Data;
    using SafeCast for uint256;
    using SafeCast for int256;
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

    /// @notice Emitted when the perps engine requests USD Token to be minted by the market making engine.
    /// @param engine The address of the engine that called the function.
    /// @param marketId The engine's market id.
    /// @param requestedUsdTokenAmount The requested amount of USD Token to minted.
    /// @param mintedUsdTokenAmount The actual amount of USD Token minted, potentially factored by the market's auto
    /// deleverage
    /// system.
    event LogWithdrawUsdTokenFromMarket(
        address indexed engine,
        uint128 indexed marketId,
        uint256 requestedUsdTokenAmount,
        uint256 mintedUsdTokenAmount
    );

    /// @notice Verifies if the caller is a registered engine.
    modifier onlyRegisteredEngine() {
        // load market making engine configuration and the perps engine address
        MarketMakingEngineConfiguration.Data storage marketMakingEngineConfiguration =
            MarketMakingEngineConfiguration.load();

        // if `msg.sender` is not a registered engine, revert
        if (!marketMakingEngineConfiguration.isRegisteredEngine[msg.sender]) {
            revert Errors.Unauthorized(msg.sender);
        }

        // continue execution
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Returns the credit capacity of the given market id.
    /// @dev `CreditDelegationBranch::updateCreditDelegation` must be called before calling this function in order to
    /// retrieve the latest state.
    /// @dev Each engine can implement its own debt accounting schema according to its business logic, thus, this
    /// function will simply return the credit capacity in USD for the given market id.
    /// @dev Invariants:
    /// The Market MUST exist.
    /// @param marketId The engine's market id.
    /// @return creditCapacityUsdX18 The current credit capacity of the given market id in USD.
    // TODO: add invariants
    function getCreditCapacityForMarketId(uint128 marketId) public view returns (SD59x18) {
        Market.Data storage market = Market.loadExisting(marketId);

        return Market.getCreditCapacityUsd(
            market.getTotalDelegatedCreditUsd(), market.getUnrealizedDebtUsd().add(market.getRealizedDebtUsd())
        );
    }

    /// @notice Returns the adjusted profit of an active position at the given market id, considering the market's ADL
    /// state.
    /// @dev If the market is in its default state, it will simply return the provided profit. Otherwise, it will
    /// adjust based on the configured ADL parameters.
    /// @dev Invariants:
    /// The Market of `marketId` MUST exist.
    /// The Market of `marketId` MUST be live.
    /// @param marketId The engine's market id.
    /// @param profitUsd The position's profit in USD.
    /// @return adjustedProfitUsdX18 The adjusted profit in USD Token, according to the market's health.
    // TODO: add invariants
    function getAdjustedProfitForMarketId(
        uint128 marketId,
        uint256 profitUsd
    )
        public
        view
        returns (UD60x18 adjustedProfitUsdX18)
    {
        // load the market's data storage pointer
        Market.Data storage market = Market.loadLive(marketId);
        // cache the market's total debt
        SD59x18 marketTotalDebtUsdX18 = market.getUnrealizedDebtUsd().add(market.getRealizedDebtUsd());
        // uint256 -> UD60x18
        UD60x18 profitUsdX18 = ud60x18(profitUsd);

        // caches the market's delegated credit
        UD60x18 delegatedCreditUsdX18 = market.getTotalDelegatedCreditUsd();
        // caches the market's credit capacity
        SD59x18 creditCapacityUsdX18 = Market.getCreditCapacityUsd(delegatedCreditUsdX18, marketTotalDebtUsdX18);

        // if the credit capacity is less than or equal to zero, it means the total debt has already taken all the
        // delegated credit
        if (creditCapacityUsdX18.lte(SD59x18_ZERO)) {
            revert Errors.InsufficientCreditCapacity(marketId, creditCapacityUsdX18.intoInt256());
        }

        // we don't need to add `profitUsd` as it's assumed to be part of the total debt
        // NOTE: If we don't return the adjusted profit in this if branch, we assume marketTotalDebtUsdX18 is positive
        if (!market.isAutoDeleverageTriggered(delegatedCreditUsdX18, marketTotalDebtUsdX18)) {
            // if the market is not in the ADL state, it returns the profit as is
            adjustedProfitUsdX18 = profitUsdX18;
            return adjustedProfitUsdX18;
        }

        // if the market's auto deleverage system is triggered, it assumes marketTotalDebtUsdX18 > 0
        adjustedProfitUsdX18 =
            market.getAutoDeleverageFactor(delegatedCreditUsdX18, marketTotalDebtUsdX18).mul(profitUsdX18);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                REGISTERED ENGINE ONLY PROTECTED FUNCTIONS
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
    /// @dev Invariants: TODO: update invariants
    ///     * market.getTotalDelegatedCreditUsd() > 0
    ///     * ERC20(collateralType).allowance(perpsEngine, marketMakingEngine) >= amount
    ///     * ERC20(collateralType).balanceOf(perpsEngine) >= amount
    ///     * market.collectedMarginCollateral.get(collateralType) ==  ∑convertTokenAmountToUd60x18(amount)
    ///     * ERC20(collateralType).balanceOf(marketMakingEngine) == ∑amount
    /// The Market of `marketId` MUST exist.
    /// The Market of `marketId` MUST be live.
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

        // loads the market's data storage pointer
        Market.Data storage market = Market.loadLive(marketId);

        // ensures that the market has delegated credit, so the engine is not depositing credit to an empty
        // distribution (with 0 total shares), although this should never happen if the system functions properly.
        if (market.getTotalDelegatedCreditUsd().isZero()) {
            revert Errors.NoDelegatedCredit(marketId);
        }

        // uint256 -> UD60x18 and scale decimals to 18
        UD60x18 amountX18 = collateral.convertTokenAmountToUd60x18(amount);

        // caches the usdToken address
        address usdToken = MarketMakingEngineConfiguration.load().usdTokenOfEngine[msg.sender];

        if (collateralType == usdToken) {
            // if the deposited collateral is USD Token, it reduces the market's realized debt
            market.realizeUsdTokenDebt(unary(amountX18.intoSD59x18()));
        } else {
            // deposits the received collateral to the market to be distributed to vaults, and then settled in the
            // future
            market.depositCollateral(collateralType, amountX18);
        }

        // transfers the margin collateral asset from the perps engine to the market making engine
        // NOTE: The engine must approve the market making engine to transfer the margin collateral asset, see
        // PerpsEngineConfigurationBranch::setMarketMakingEngineAllowance
        IERC20(collateralType).safeTransferFrom(msg.sender, address(this), amount);

        // emit an event
        emit LogDepositCreditForMarket(msg.sender, marketId, collateralType, amount);
    }

    /// @notice Mints the requested amount of USD Token to the caller and updates the market's
    /// debt state.
    /// @dev Called by a registered engine to mint USD Token to profitable traders.
    /// @dev USD Token association with an engine's user happens at the engine contract level.
    /// @dev We assume `amount` is part of the market's reported unrealized debt.
    /// @dev Invariants:
    /// The Market of `marketId` MUST exist.
    /// The Market of `marketId` MUST be live.
    /// @param marketId The engine's market id requesting USD Token.
    /// @param amount The amount of USD Token to mint.
    function withdrawUsdTokenFromMarket(uint128 marketId, uint256 amount) external onlyRegisteredEngine {
        // loads the market's data storage pointer
        Market.Data storage market = Market.loadLive(marketId);
        // caches the market's unrealized debt
        SD59x18 unrealizedDebtUsdX18 = market.getUnrealizedDebtUsd();
        // caches the market's realized debt
        SD59x18 realizedDebtUsdX18 = market.getRealizedDebtUsd();

        // uint256 -> UD60x18
        // NOTE: we don't need to scale decimals here as it's known that USD Token has 18 decimals
        UD60x18 amountX18 = ud60x18(amount);

        // load the market's connected vaults ids and `mstore` them
        // TODO: is it more gas efficient if we pass the market id to the next function and load each vault at its
        // loop?
        uint256[] memory connectedVaults = market.getConnectedVaultsIds();

        // distributes the up to date unrealized and realized debt values to the market's connected vaults
        market.distributeDebtToVaults(unrealizedDebtUsdX18, realizedDebtUsdX18);

        // once the unrealized debt is distributed, we need to update the credit delegated by these vaults to the
        // market
        Vault.recalculateVaultsCreditCapacity(connectedVaults);

        // cache the market's total debt
        SD59x18 marketTotalDebtUsdX18 = unrealizedDebtUsdX18.add(realizedDebtUsdX18);

        // cache the market's delegated credit
        UD60x18 delegatedCreditUsdX18 = market.getTotalDelegatedCreditUsd();
        // cache the market's credit capacity
        SD59x18 creditCapacityUsdX18 = Market.getCreditCapacityUsd(delegatedCreditUsdX18, marketTotalDebtUsdX18);

        // enforces that the market has enough credit capacity, if it' a listed market it must always have some
        // delegated credit, see Vault.Data.lockedCreditRatio.
        // NOTE: additionally, the ADL system if functioning properly must ensure that the market always has credit
        // capacity to cover USD Token mint requests. Deleverage happens when the perps engine calls
        // CreditDelegationBranch::getAdjustedProfitForMarketId.
        // NOTE: however, it still is possible to fall into a scenario where the credit capacity is <= 0, as the
        // delegated credit may be provided in form of volatile collateral assets, which could go down in value as
        // debt reaches its ceiling. In that case, the market will run out of mintable USD Token and the mm engine
        // must
        // settle all outstanding debt for USDC, in order to keep previously paid USD Token fully backed.
        if (creditCapacityUsdX18.lt(SD59x18_ZERO)) {
            revert Errors.InsufficientCreditCapacity(marketId, creditCapacityUsdX18.intoInt256());
        }

        // prepare the amount of usdToken that will be minted to the perps engine
        uint256 amountToMint;

        // now we realize the added usd debt of the market
        // note: USD Token is assumed to be 1:1 with the system's usd accounting
        if (market.isAutoDeleverageTriggered(delegatedCreditUsdX18, marketTotalDebtUsdX18)) {
            // if the market is in the ADL state, it reduces the requested USD Token amount by multiplying it by the
            // ADL factor, which must be < 1
            UD60x18 adjustedUsdTokenToMintX18 =
                market.getAutoDeleverageFactor(delegatedCreditUsdX18, marketTotalDebtUsdX18).mul(amountX18);
            amountToMint = adjustedUsdTokenToMintX18.intoUint256();
            market.realizeUsdTokenDebt(adjustedUsdTokenToMintX18.intoSD59x18());
        } else {
            // if the market is not in the ADL state, it realizes the full requested USD Token amount
            amountToMint = amountX18.intoUint256();
            market.realizeUsdTokenDebt(amountX18.intoSD59x18());
        }

        // loads the market making engine configuration storage pointer
        MarketMakingEngineConfiguration.Data storage marketMakingEngineConfiguration =
            MarketMakingEngineConfiguration.load();
        // cache the USD Token address
        UsdToken usdToken = UsdToken(marketMakingEngineConfiguration.usdTokenOfEngine[msg.sender]);

        // mints USD Token to the perps engine
        usdToken.mint(msg.sender, amountToMint);

        // emit an event
        emit LogWithdrawUsdTokenFromMarket(msg.sender, marketId, amount, amountToMint);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   UNPROTECTED FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Converts ZLP Vaults unsettled debt to settled debt by:
    ///     - Swapping the balance of collected margin collateral to USDC, if available.
    ///     - Swapping the ZLP Vaults assets to USDC, according to the state of
    /// `SystemDebt.vaultsDebtSettlementPriorityQueue`.
    /// @dev USDC acquired from onchain markets is stored and used to cover future USD Token swaps.
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
    // TODO: update credit delegation and debt distribution
    // TODO: how to account for collected margin collateral's fluctuation in value?
    function updateCreditDelegation(uint128 marketId) public { }

    /// @dev Called by the perps trading engine to update the credit delegation and return the credit for a given
    /// market id
    /// @dev Invariants involved in the call:
    /// @param marketId The engine's market id.
    /// @return creditCapacityUsdX18 The current credit capacity of the given market id in USD.
    /// TODO: add invariants
    function updateCreditDelegationAndReturnCreditForMarket(uint128 marketId) external returns (SD59x18) {
        updateCreditDelegation(marketId);
        return getCreditCapacityForMarketId(marketId);
    }

    /// @notice Updates the credit capacity of the given vault id, recalculating its connected markets' debt and its
    /// collateral assets USD value.
    /// @param vaultId The vault identifier.
    function updateVaultCreditCapacity(uint128 vaultId) external {
        // prepare the `Vault::recalculateVaultsCreditCapacity` call
        uint256[] memory vaultsIds = new uint256[](1);
        vaultsIds[0] = uint256(vaultId);

        // updates the vault's credit capacity
        Vault.recalculateVaultsCreditCapacity(vaultsIds);
    }
}
