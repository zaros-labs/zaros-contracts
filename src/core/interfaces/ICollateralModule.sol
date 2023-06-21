//SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

// Zaros dependencies
import { CollateralConfig } from "../storage/CollateralConfig.sol";

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";

/**
 * @title Module for managing user collateral.
 * @notice Allows users to deposit and withdraw collateral from the system.
 */
interface ICollateralModule {
    error Zaros_CollateralModule_InvalidConfiguration(CollateralConfig.Data config);

    /**
     * @notice Thrown when an interacting account does not have sufficient collateral for an operation (withdrawal,
     * lock, etc).
     */
    error Zaros_CollateralModule_InsufficientAccountCollateral(uint256 amount);

    /**
     * @notice Emitted when a collateral type’s configuration is created or updated.
     * @param collateralType The address of the collateral type that was just configured.
     * @param config The object with the newly configured details.
     */
    event LogConfigureCollateral(address indexed collateralType, CollateralConfig.Data config);

    /**
     * @notice Emitted when `tokenAmount` of collateral of type `collateralType` is deposited to account `accountId` by
     * `sender`.
     * @param accountId The id of the account that deposited collateral.
     * @param collateralType The address of the collateral that was deposited.
     * @param tokenAmount The amount of collateral that was deposited, denominated in the token's native decimal
     * representation.
     * @param sender The address of the account that triggered the deposit.
     */
    event LogDeposit(
        uint128 indexed accountId, address indexed collateralType, uint256 tokenAmount, address indexed sender
    );

    /**
     * @notice Emitted when `tokenAmount` of collateral of type `collateralType` is withdrawn from account `accountId`
     * by
     * `sender`.
     * @param accountId The id of the account that withdrew collateral.
     * @param collateralType The address of the collateral that was withdrawn.
     * @param tokenAmount The amount of collateral that was withdrawn, denominated in the token's native decimal
     * representation.
     * @param sender The address of the account that triggered the withdrawal.
     */
    event LogWithdrawal(
        uint128 indexed accountId, address indexed collateralType, uint256 tokenAmount, address indexed sender
    );

    /**
     * @notice Creates or updates the configuration for the given `collateralType`.
     * @param config The CollateralConfig object describing the new configuration.
     *
     * Requirements:
     *
     * - `msg.sender` must be the owner of the system.
     *
     * Emits a {LogConfigureCollateral} event.
     *
     */
    function configureCollateral(CollateralConfig.Data memory config) external;

    /**
     * @notice Returns a list of detailed information pertaining to all collateral types registered in the system.
     * @dev Optionally returns only those that are currently enabled.
     * @param hideDisabled Wether to hide disabled collaterals or just return the full list of collaterals in the
     * system.
     * @return collaterals The list of collateral configuration objects set in the system.
     */
    function getCollateralConfigs(bool hideDisabled)
        external
        view
        returns (CollateralConfig.Data[] memory collaterals);

    /**
     * @notice Returns detailed information pertaining the specified collateral type.
     * @param collateralType The address for the collateral whose configuration is being queried.
     * @return collateral The configuration object describing the given collateral.
     */
    function getCollateralConfig(address collateralType)
        external
        view
        returns (CollateralConfig.Data memory collateral);

    /**
     * @notice Returns the current value of a specified collateral type.
     * @param collateralType The address for the collateral whose price is being queried.
     * @return price The price of the given collateral, denominated with 18 decimals of precision.
     */
    function getCollateralPrice(address collateralType) external view returns (UD60x18 price);

    /**
     * @notice Deposits `tokenAmount` of collateral of type `collateralType` into account `accountId`.
     * @dev Anyone can deposit into anyone's active account without restriction.
     * @param accountId The id of the account that is making the deposit.
     * @param collateralType The address of the token to be deposited.
     * @param tokenAmount The amount being deposited, denominated in the token's native decimal representation.
     *
     * Emits a {Deposited} event.
     */
    function deposit(uint128 accountId, address collateralType, uint256 tokenAmount) external;

    /**
     * @notice Withdraws `tokenAmount` of collateral of type `collateralType` from account `accountId`.
     * @param accountId The id of the account that is making the withdrawal.
     * @param collateralType The address of the token to be withdrawn.
     * @param tokenAmount The amount being withdrawn, denominated in the token's native decimal representation.
     *
     * Requirements:
     *
     * - `msg.sender` must be the owner of the account, have the `ADMIN` permission, or have the `WITHDRAW` permission.
     *
     * Emits a {Withdrawn} event.
     *
     */
    function withdraw(uint128 accountId, address collateralType, uint256 tokenAmount) external;

    /**
     * @notice Returns the total values pertaining to account `accountId` for `collateralType`.
     * @param accountId The id of the account whose collateral is being queried.
     * @param collateralType The address of the collateral type whose amount is being queried.
     * @return totalDeposited The total collateral deposited in the account, denominated with 18 decimals of precision.
     * @return totalAssigned The amount of collateral in the account that is delegated to pools, denominated with 18
     * decimals of precision.
     */
    function getAccountCollateral(
        uint128 accountId,
        address collateralType
    )
        external
        view
        returns (UD60x18 totalDeposited, UD60x18 totalAssigned);

    /**
     * @notice Returns the amount of collateral of type `collateralType` deposited with account `accountId` that can be
     * withdrawn or delegated to pools.
     * @param accountId The id of the account whose collateral is being queried.
     * @param collateralType The address of the collateral type whose amount is being queried.
     * @return amount The amount of collateral that is available for withdrawal or delegation, denominated with 18
     * decimals of precision.
     */
    function getAccountAvailableCollateral(
        uint128 accountId,
        address collateralType
    )
        external
        view
        returns (UD60x18 amount);
}
