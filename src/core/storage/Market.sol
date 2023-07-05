//SPDX-License-Identifier: MIT
pragma solidity >=0.8.11 <0.9.0;

// Zaros dependencies
import { Distribution } from "./Distribution.sol";
import { CollateralConfig } from "./CollateralConfig.sol";
import { IMarket } from "../interfaces/external/IMarket.sol";

// Open Zeppelin dependencies
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18, ZERO as UD_ZERO, UNIT as UD_UNIT, MAX_UD60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, ZERO as SD_ZERO } from "@prb-math/SD59x18.sol";

/**
 * @title Connects external contracts that implement the `IMarket` interface to the system.
 *
 * Pools provide credit capacity (collateral) to the markets, and are reciprocally exposed to the associated market's
 * debt.
 *
 * The Market object's main responsibility is to track collateral provided by the pools that support it, and to trace
 * their debt back to such pools.
 */

library Market {
    using Distribution for Distribution.Data;

    /**
     * @dev Thrown when a specified market is not found.
     */
    error MarketNotFound(uint128 marketId);

    /// @dev Constant base domain used to access a given market's storage slot
    string internal constant MARKET_DOMAIN = "fi.zaros.core.Market";

    struct Data {
        /**
         * @dev Address for the external contract that implements the `IMarket` interface, which this Market objects
         * connects to.
         *
         * Note: This object is how the system tracks the market. The actual market is external to the system, i.e. its
         * own contract.
         */
        address marketAddress;
        /**
         * @dev Issuance can be seen as how much USD the Market "has issued", printed, or has asked the system to mint
         * on its behalf.
         *
         * More precisely it can be seen as the net difference between the USD burnt and the USD minted by the market.
         *
         * More issuance means that the market owes more USD to the system.
         *
         * A market burns USD when users deposit it in exchange for some asset that the market offers.
         * The Market object calls `MarketManager.depositUSD()`, which burns the USD, and decreases its issuance.
         *
         * A market mints USD when users return the asset that the market offered and thus withdraw their USD.
         * The Market object calls `MarketManager.withdrawUSD()`, which mints the USD, and increases its issuance.
         *
         * Instead of burning, the Market object could transfer USD to and from the MarketManager, but minting and
         * burning takes the USD out of circulation, which doesn't affect `totalSupply`, thus simplifying accounting.
         *
         * How much USD a market can mint depends on how much credit capacity is given to the market by the pools that
         * support it, and reflected in `Market.capacity`.
         *
         */
        int128 netIssuanceD18;
        /**
         * @dev The total amount of USD that the market could withdraw if it were to immediately unwrap all its
         * positions.
         *
         * The Market's credit capacity increases when the market burns USD, i.e. when it deposits USD in the
         * MarketManager.
         *
         * It decreases when the market mints USD, i.e. when it withdraws USD from the MarketManager.
         *
         * The Market's credit capacity also depends on how much credit is given to it by the pools that support it.
         *
         * The Market's credit capacity also has a dependency on the external market reported debt as it will respond to
         * that debt (and hence change the credit capacity if it increases or decreases)
         *
         * The credit capacity can go negative if all of the collateral provided by pools is exhausted, and there is
         * market provided collateral available to consume. in this case, the debt is still being
         * appropriately assigned, but the market has a dynamic cap based on deposited collateral types.
         *
         */
        int128 creditCapacityD18;
        /**
         * @dev The amount of debt the pool has which hasn't been passed down the debt distribution chain yet.
         */
        uint128 pendingDebtD18;
        /**
         * @dev The total balance that the market had the last time that its debt was distributed.
         *
         * A Market's debt is distributed when the reported debt of its associated external market is rolled into the
         * pools that provide credit capacity to it.
         */
        int128 lastDistributedMarketBalanceD18;
        uint128 depositedUSDCollateral;
        /**
         * @dev Market-specific override of the minimum liquidity ratio
         */
        uint128 minLiquidityRatioD18;
        uint32 minDelegateTime;
    }

    /**
     * @dev Data structure that allows the Market to track the amount of market provided collateral, per type.
     */
    struct DepositedCollateral {
        address collateralType;
        uint256 amountD18;
    }

    /**
     * @dev Returns the market stored at the specified market id.
     */
    function load(address marketAddress) internal pure returns (Data storage market) {
        bytes32 s = keccak256(abi.encode(MARKET_DOMAIN, marketAddress));
        assembly {
            market.slot := s
        }
    }

    /**
     * @dev Queries the external market contract for the amount of debt it has issued.
     *
     * The reported debt of a market represents the amount of USD that the market would ask the system to mint, if all
     * of its positions were to be immediately closed.
     *
     * The reported debt of a market is collateralized by the assets in the pools which back it.
     *
     * See the `IMarket` interface.
     */
    function getReportedDebt(Data storage self) internal view returns (UD60x18) {
        return ud60x18(IMarket(self.marketAddress).reportedDebt());
    }

    /**
     * @dev Queries the market for the amount of collateral which should be prevented from withdrawal.
     */
    function getLockedCreditCapacity(Data storage self) internal view returns (UD60x18) {
        return ud60x18(IMarket(self.marketAddress).minimumCredit());
    }

    /**
     * @dev Returns the total debt of the market.
     *
     * A market's total debt represents its debt plus its issuance, and thus represents the total outstanding debt of
     * the market.
     *
     * Note: it also takes into account the deposited collateral value. See note in  getDepositedCollateralValue()
     *
     * Example:
     * (1 EUR = 1.11 USD)
     * If an Euro market has received 100 USD to mint 90 EUR, its reported debt is 90 EUR or 100 USD, and its issuance
     * is -100 USD.
     * Thus, its total balance is 100 USD of reported debt minus 100 USD of issuance, which is 0 USD.
     *
     * Additionally, the market's totalDebt might be affected by price fluctuations via reportedDebt, or fees.
     *
     */
    function totalDebt(Data storage self) internal view returns (SD59x18) {
        return getReportedDebt(self).intoSD59x18().add(sd59x18(self.netIssuanceD18)).sub(
            ud60x18(self.depositedUSDCollateral).intoSD59x18()
        );
    }

    /**
     * @dev Returns the USD value for the total amount of collateral provided by the market itself.
     *
     * Note: This is not credit capacity provided by depositors through pools.
     */
    function getDepositedCollateralValue(Data storage self) internal view returns (UD60x18) {
        return ud60x18(self.depositedUSDCollateral);
    }

    /**
     * @dev Returns true if the market's current capacity is below the amount of locked capacity.
     *
     */
    function isCapacityLocked(Data storage self) internal view returns (bool) {
        return sd59x18(self.creditCapacityD18).lt(getLockedCreditCapacity(self).intoSD59x18());
    }
}
