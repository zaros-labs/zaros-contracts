// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { IAccountNFT } from "@zaros/account-nft/interfaces/IAccountNFT.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { IPerpsAccountModule } from "../interfaces/IPerpsAccountModule.sol";
import { PerpsAccount } from "../storage/PerpsAccount.sol";
import { GlobalConfiguration } from "../storage/GlobalConfiguration.sol";
import { PerpMarket } from "../storage/PerpMarket.sol";
import { Position } from "../storage/Position.sol";
import { MarginCollateralConfiguration } from "../storage/MarginCollateralConfiguration.sol";

// Open Zeppelin dependencies
import { EnumerableMap } from "@openzeppelin/utils/structs/EnumerableMap.sol";
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { IERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";
import { SafeERC20 } from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, ZERO as SD_ZERO } from "@prb-math/SD59x18.sol";

/// @notice See {IPerpsAccountModule}.
abstract contract PerpsAccountModule is IPerpsAccountModule {
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;
    using PerpsAccount for PerpsAccount.Data;
    using PerpMarket for PerpMarket.Data;
    using Position for Position.Data;
    using SafeCast for uint256;
    using SafeERC20 for IERC20;
    using GlobalConfiguration for GlobalConfiguration.Data;
    using MarginCollateralConfiguration for MarginCollateralConfiguration.Data;

    function isAuthorized(uint128 accountId, address sender) external view returns (bool) {
        PerpsAccount.Data storage perpsAccount = PerpsAccount.load(accountId);

        return perpsAccount.owner == sender;
    }

    /// @inheritdoc IPerpsAccountModule
    function getPerpsAccountToken() public view override returns (address) {
        return GlobalConfiguration.load().perpsAccountToken;
    }

    /// @inheritdoc IPerpsAccountModule
    function getAccountMarginCollateralBalance(
        uint128 accountId,
        address collateralType
    )
        external
        view
        override
        returns (UD60x18)
    {
        PerpsAccount.Data storage perpsAccount = PerpsAccount.load(accountId);
        UD60x18 marginCollateralBalanceX18 = perpsAccount.getMarginCollateralBalance(collateralType);

        return marginCollateralBalanceX18;
    }

    /// @inheritdoc IPerpsAccountModule
    function getAccountEquityUsd(
        uint128 accountId,
        uint128[] calldata activeMarketsIds,
        UD60x18[] calldata indexPricesX18
    )
        external
        view
        override
        returns (SD59x18)
    {
        PerpsAccount.Data storage perpsAccount = PerpsAccount.load(accountId);
        SD59x18 activePositionsUnrealizedPnlUsdX18 =
            getAccountTotalUnrealizedPnl(accountId, activeMarketsIds, indexPricesX18);

        return perpsAccount.getEquityUsdX18(activePositionsUnrealizedPnlUsdX18);
    }

    /// @inheritdoc IPerpsAccountModule
    function getAccountMarginBreakdown(uint128 accountId)
        external
        view
        override
        returns (SD59x18, SD59x18, UD60x18, UD60x18)
    {
        PerpsAccount.Data storage perpsAccount = PerpsAccount.load(accountId);

        // SD59x18 marginBalanceUsdX18 = perpsAccount.getEquityUsdX18();
        SD59x18 marginBalanceUsdX18;
        UD60x18 initialMarginUsdX18;
        UD60x18 maintenanceMarginUsdX18;

        for (uint256 i = 0; i < perpsAccount.activeMarketsIds.length(); i++) {
            uint128 marketId = perpsAccount.activeMarketsIds.at(i).toUint128();
            PerpMarket.Data storage perpMarket = PerpMarket.load(marketId);
            Position.Data storage position = Position.load(accountId, marketId);

            // TODO: work on this on a separate task
            UD60x18 marketMarkPrice;
            // UD60x18 marketMarkPrice = perpMarket.getIndexPrice();
            SD59x18 fundingRate = perpMarket.getCurrentFundingRate();
            SD59x18 fundingFeePerUnit = perpMarket.getNextFundingFeePerUnit(fundingRate, marketMarkPrice);
            UD60x18 notionalValueX18 = position.getNotionalValue(marketMarkPrice);

            marginBalanceUsdX18 = marginBalanceUsdX18.add(position.getUnrealizedPnl(marketMarkPrice)).add(
                position.getAccruedFunding(fundingFeePerUnit)
            );
            // initialMarginUsdX18 = initialMarginUsdX18.add(ud60x18(position.initialMarginUsdX18));
            maintenanceMarginUsdX18 = maintenanceMarginUsdX18.add(
                ud60x18(perpMarket.configuration.maintenanceMarginRate).mul(notionalValueX18)
            );
        }

        SD59x18 availableBalance = marginBalanceUsdX18.sub(initialMarginUsdX18.intoSD59x18());

        return (marginBalanceUsdX18, availableBalance, initialMarginUsdX18, maintenanceMarginUsdX18);
    }

    /// @inheritdoc IPerpsAccountModule
    function getAccountTotalUnrealizedPnl(
        uint128 accountId,
        uint128[] calldata activeMarketsIds,
        UD60x18[] calldata indexPricesX18
    )
        public
        view
        returns (SD59x18 accountTotalUnrealizedPnlUsdX18)
    {
        SD59x18 accountTotalUnrealizedPnlUsdX18;

        for (uint256 i = 0; i < activeMarketsIds.length; i++) {
            uint128 marketId = activeMarketsIds[i];
            PerpMarket.Data storage perpMarket = PerpMarket.load(marketId);
            Position.Data storage position = Position.load(accountId, marketId);

            // we don't need to revert as this function is consumed by the client only and trusts
            // the inputs
            if (position.size == 0) {
                continue;
            }

            UD60x18 markPrice = perpMarket.getMarkPrice(SD_ZERO, indexPricesX18[i]);
            SD59x18 unrealizedPnlUsdX18 = position.getUnrealizedPnl(markPrice);

            accountTotalUnrealizedPnlUsdX18 = accountTotalUnrealizedPnlUsdX18.add(unrealizedPnlUsdX18);
        }
    }

    /// @inheritdoc IPerpsAccountModule
    function getActiveMarketsIds(uint128 accountId) external view returns (uint256[] memory activeMarketsIds) { }

    /// @inheritdoc IPerpsAccountModule
    function getOpenPositionData(
        uint128 accountId,
        uint128 marketId,
        uint256 indexPriceX18
    )
        external
        view
        override
        returns (
            SD59x18 openInterest,
            UD60x18 notionalValueX18,
            UD60x18 maintenanceMarginUsdX18,
            SD59x18 accruedFundingUsdX18,
            SD59x18 unrealizedPnlUsdX18
        )
    {
        PerpMarket.Data storage perpMarket = PerpMarket.load(marketId);
        Position.Data storage position = Position.load(accountId, marketId);

        // UD60x18 maintenanceMarginRate = ud60x18(perpMarket.maintenanceMarginRate);
        UD60x18 price = perpMarket.getMarkPrice(SD_ZERO, ud60x18(indexPriceX18));
        SD59x18 fundingRate = perpMarket.getCurrentFundingRate();
        SD59x18 fundingFeePerUnit = perpMarket.getNextFundingFeePerUnit(fundingRate, price);

        (openInterest, notionalValueX18, maintenanceMarginUsdX18, accruedFundingUsdX18, unrealizedPnlUsdX18) =
        position.getPositionData(ud60x18(perpMarket.configuration.maintenanceMarginRate), price, fundingFeePerUnit);
    }

    /// @inheritdoc IPerpsAccountModule
    function createPerpsAccount() public override returns (uint128) {
        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();
        uint128 accountId = ++globalConfiguration.nextAccountId;
        IAccountNFT perpsAccountToken = IAccountNFT(globalConfiguration.perpsAccountToken);
        perpsAccountToken.mint(msg.sender, accountId);

        PerpsAccount.create(accountId, msg.sender);

        emit LogCreatePerpsAccount(accountId, msg.sender);
        return accountId;
    }

    /// @inheritdoc IPerpsAccountModule
    function createPerpsAccountAndMulticall(bytes[] calldata data)
        external
        payable
        override
        returns (bytes[] memory results)
    {
        uint128 accountId = createPerpsAccount();

        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            bytes memory dataWithAccountId = abi.encodePacked(data[i][0:4], abi.encode(accountId), data[i][4:]);
            (bool success, bytes memory result) = address(this).delegatecall(dataWithAccountId);

            if (!success) {
                uint256 len = result.length;
                assembly {
                    revert(add(result, 0x20), len)
                }
            }

            results[i] = result;
        }
    }

    /// @inheritdoc IPerpsAccountModule
    function depositMargin(uint128 accountId, address collateralType, uint256 amount) external override {
        // GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();
        MarginCollateralConfiguration.Data storage marginCollateralConfiguration =
            MarginCollateralConfiguration.load(collateralType);
        UD60x18 ud60x18Amount = marginCollateralConfiguration.convertTokenAmountToUd60x18(amount);
        _requireAmountNotZero(ud60x18Amount);
        _requireEnoughDepositCap(collateralType, ud60x18Amount, marginCollateralConfiguration.getDepositCap());

        PerpsAccount.Data storage perpsAccount = PerpsAccount.loadExisting(accountId);
        perpsAccount.deposit(collateralType, ud60x18Amount);
        IERC20(collateralType).safeTransferFrom(msg.sender, address(this), ud60x18Amount.intoUint256());

        emit LogDepositMargin(msg.sender, accountId, collateralType, amount);
    }

    /// @inheritdoc IPerpsAccountModule
    function withdrawMargin(uint128 accountId, address collateralType, UD60x18 ud60x18Amount) external override {
        _requireAmountNotZero(ud60x18Amount);

        PerpsAccount.Data storage perpsAccount = PerpsAccount.loadExistingAccountAndVerifySender(accountId);
        _checkMarginIsAvailable(perpsAccount, collateralType, ud60x18Amount);
        perpsAccount.withdraw(collateralType, ud60x18Amount);

        MarginCollateralConfiguration.Data storage marginCollateralConfiguration =
            MarginCollateralConfiguration.load(collateralType);
        uint256 tokenAmount = marginCollateralConfiguration.convertUd60x18ToTokenAmount(ud60x18Amount);
        IERC20(collateralType).safeTransfer(msg.sender, tokenAmount);

        emit LogWithdrawMargin(msg.sender, accountId, collateralType, tokenAmount);
    }

    /// @inheritdoc IPerpsAccountModule
    function notifyAccountTransfer(address to, uint128 accountId) external override {
        _onlyPerpsAccountToken();

        PerpsAccount.Data storage perpsAccount = PerpsAccount.load(accountId);
        perpsAccount.owner = to;
    }

    /// @dev Reverts if the amount is zero.
    function _requireAmountNotZero(UD60x18 amount) internal pure {
        if (amount.isZero()) {
            revert Errors.ZeroInput("amount");
        }
    }

    /// @dev Reverts if the collateral type is not supported.
    function _requireEnoughDepositCap(address collateralType, UD60x18 amount, UD60x18 depositCap) internal pure {
        if (amount.gt(depositCap)) {
            revert Errors.DepositCap(collateralType, amount.intoUint256(), depositCap.intoUint256());
        }
    }

    /// @dev Checks if the requested amount of margin collateral is available to be withdrawn.
    /// @dev Iterates over active positions in order to take uPnL and margin requirements into account.
    /// @param perpsAccount The perps account storage pointer.
    /// @param collateralType The margin collateral address.
    /// @param amount The amount of margin collateral to be withdrawn.
    function _checkMarginIsAvailable(
        PerpsAccount.Data storage perpsAccount,
        address collateralType,
        UD60x18 amount
    )
        internal
        view
    { }

    /// @dev Reverts if the caller is not the account owner.
    function _onlyPerpsAccountToken() internal view {
        if (msg.sender != address(getPerpsAccountToken())) {
            revert Errors.OnlyPerpsAccountToken(msg.sender);
        }
    }
}
