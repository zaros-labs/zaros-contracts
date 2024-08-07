// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

/// @dev This contract deals with USDC to settle protocol debt, used to back USDz
contract CreditDelegationBranch {
    /// @dev Returns the OI and skew caps for the given market id.
    /// @dev `CreditDelegationBranch::updateCreditDelegation` must be called before calling this function in order to
    /// retrieve the latest state.
    function getCreditForMarketId(uint128 marketId) public view returns (uint256 openInterestCap, uint256 skewCap) { }

    /// @dev Called by the perps engine to send margin collateral deducted from a trader's account during a negative
    /// pnl settlement or a liquidation event.
    function receiveMarginCollateral(address collateralType, uint256 amount) external { }

    /// @dev Should settle vault's unsettled debt by converting the balance of different margin collateral types to
    /// USDC, stored and used to cover future USDz swaps, and settle credit by converting the collected margin
    /// collateral balance to the vaults' underlying assets.
    /// @dev Settlement Priority:
    /// 1. highest to lowest debt.
    /// 2. highest to lowest credit.
    /// @dev The protocol should also take into account the global debt state. E.g: if the protocol is in credit state
    /// but a given vault is in net debt due to swaps, other vaults' exceeding credit (i.e exceeding assets) can be
    /// converted to the in debt vault's underlying assets. If the protocol is in debt state but there's a vault with
    /// net credit due to swaps, the protocol can rebalance other vaults by distributing exceeding assets from that
    /// vault.
    /// @dev In order to determine the logic above, it should be taken into account a vault's participation in the
    /// global debt or credit. E.g if the protocol is in a given state and a new ZLP vault is added, this new vault is
    /// neutral compared to the others that may be in credit or debt state.
    function settleVaultsDebt() external { }

    /// @dev Must be called whenever the perps trading engine needs to know a market's skew and OI caps.
    /// @dev It takes into accounts all vault's credit delegated to each available markets. N Vaults may delegate
    /// credit to N markets, configured by the protocol admin.
    function updateCreditDelegation() public { }

    /// @dev Called by the perps trading engine to update the credit delegation and return the credit for a given
    /// market id
    function updateCreditDelegationAndReturnCreditForMarketId(uint128 marketId)
        external
        returns (uint256 openInterestCap, uint256 skewCap)
    {
        updateCreditDelegation();
        return getCreditForMarketId(marketId);
    }
}
