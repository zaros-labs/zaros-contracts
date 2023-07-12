// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { Constants } from "../../utils/Constants.sol";
import { ParameterError } from "../../utils/Errors.sol";
import { FeatureFlag } from "../../utils/storage/FeatureFlag.sol";
import { IMarketManagerModule } from "../interfaces/IMarketManagerModule.sol";
import { Market } from "../storage/Market.sol";
import { MarketManager } from "../storage/MarketManager.sol";
import { MarketConfiguration } from "../storage/MarketConfiguration.sol";

// Open Zeppelin dependencies
import { Ownable } from "@openzeppelin/access/Ownable.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

// TODO: implement fees
contract MarketManagerModule is IMarketManagerModule, Ownable {
    using Market for Market.Data;
    using MarketManager for MarketManager.Data;
    using SafeCast for uint256;

    bytes32 private constant _MARKET_FEATURE_FLAG = "registerMarket";
    bytes32 private constant _DEPOSIT_MARKET_FEATURE_FLAG = "depositMarketUsd";
    bytes32 private constant _WITHDRAW_MARKET_FEATURE_FLAG = "withdrawMarketUsd";

    function getWithdrawableMarketUsd(address marketAddress) public view override returns (uint256) {
        return ud60x18(Market.load(marketAddress).creditCapacity).add(
            Market.load(marketAddress).getDepositedCollateralValue()
        ).intoUint256();
    }

    function getMarketNetIssuance(address marketAddress) external view override returns (int128) {
        return Market.load(marketAddress).netIssuance;
    }

    function getMarketReportedDebt(address marketAddress) external view override returns (uint256) {
        return Market.load(marketAddress).getReportedDebt().intoUint256();
    }

    function getMarketCollateral(address marketAddress) external view override returns (uint256) {
        return Market.load(marketAddress).creditCapacity;
    }

    function getMarketTotalDebt(address marketAddress) external view override returns (int256) {
        return Market.load(marketAddress).totalDebt().intoInt256();
    }

    function getMarketDebtPerCredit(address marketAddress) external override returns (int256) {
        Market.Data storage market = Market.load(marketAddress);

        return market.getDebtPerCredit().intoInt256();
    }

    /**
     * @inheritdoc IMarketManagerModule
     */
    function isMarketCapacityLocked(address marketAddress) external view override returns (bool) {
        return Market.load(marketAddress).isCapacityLocked();
    }

    function getZarosUsd() external view override returns (address) {
        return MarketManager.load().zrsUsd;
    }

    // /**
    //  * @inheritdoc IMarketManagerModule
    //  */
    // function depositMarketUsd(
    //     address marketAddress,
    //     address target,
    //     uint256 amount
    // ) external override returns (uint256 feeAmount) {
    //     FeatureFlag.ensureAccessToFeature(_DEPOSIT_MARKET_FEATURE_FLAG);
    //     Market.Data storage market = Market.load(marketAddress);

    //     // Call must come from the market itself.
    //     if (msg.sender != market.marketAddress) revert AccessError.Unauthorized(msg.sender);

    //     feeAmount = amount.mulDecimal(Config.readUint(_CONFIG_DEPOSIT_MARKET_USD_FEE_RATIO, 0));
    //     address feeAddress = feeAmount > 0
    //         ? Config.readAddress(_CONFIG_DEPOSIT_MARKET_USD_FEE_ADDRESS, address(0))
    //         : address(0);

    //     // verify if the market is authorized to burn the USD for the target
    //     ITokenModule usdToken = AssociatedSystem.load(_USD_TOKEN).asToken();

    //     // Adjust accounting.
    //     market.creditCapacity += (amount - feeAmount).toInt().to128();
    //     market.netIssuance -= (amount - feeAmount).toInt().to128();

    //     // Burn the incoming USD.
    //     // Note: Instead of burning, we could transfer USD to and from the MarketManager,
    //     // but minting and burning takes the USD out of circulation,
    //     // which doesn't affect `totalSupply`, thus simplifying accounting.
    //     IUSDTokenModule(address(usdToken)).burnWithAllowance(target, msg.sender, amount);

    //     if (feeAmount > 0 && feeAddress != address(0)) {
    //         IUSDTokenModule(address(usdToken)).mint(feeAddress, feeAmount);

    //         emit MarketSystemFeePaid(marketAddress, feeAmount);
    //     }

    //     emit MarketUsdDeposited(marketAddress, target, amount, msg.sender);
    // }

    // /**
    //  * @inheritdoc IMarketManagerModule
    //  */
    // function withdrawMarketUsd(
    //     address marketAddress,
    //     address target,
    //     uint256 amount
    // ) external override returns (uint256 feeAmount) {
    //     FeatureFlag.ensureAccessToFeature(_WITHDRAW_MARKET_FEATURE_FLAG);
    //     Market.Data storage marketData = Market.load(marketAddress);

    //     // Call must come from the market itself.
    //     if (msg.sender != marketData.marketAddress) revert AccessError.Unauthorized(msg.sender);

    //     // Ensure that the market's balance allows for this withdrawal.
    //     feeAmount = amount.mulDecimal(Config.readUint(_CONFIG_WITHDRAW_MARKET_USD_FEE_RATIO, 0));
    //     if (amount + feeAmount > getWithdrawableMarketUsd(marketAddress))
    //         revert NotEnoughLiquidity(marketAddress, amount);

    //     address feeAddress = feeAmount > 0
    //         ? Config.readAddress(_CONFIG_WITHDRAW_MARKET_USD_FEE_ADDRESS, address(0))
    //         : address(0);

    //     // Adjust accounting.
    //     marketData.creditCapacity -= (amount + feeAmount).toInt().to128();
    //     marketData.netIssuance += (amount + feeAmount).toInt().to128();

    //     // Mint the requested USD.
    //     AssociatedSystem.load(_USD_TOKEN).asToken().mint(target, amount);

    //     if (feeAmount > 0 && feeAddress != address(0)) {
    //         AssociatedSystem.load(_USD_TOKEN).asToken().mint(feeAddress, feeAmount);

    //         emit MarketSystemFeePaid(marketAddress, feeAmount);
    //     }

    //     emit MarketUsdWithdrawn(marketAddress, target, amount, msg.sender);
    // }

    /**
     * @inheritdoc IMarketManagerModule
     */
    function getMinLiquidityRatio(address marketAddress) external view override returns (uint256) {
        return Market.load(marketAddress).minLiquidityRatio;
    }

    /**
     * @inheritdoc IMarketManagerModule
     */
    function setMinLiquidityRatio(address marketAddress, uint128 minLiquidityRatio) external override onlyOwner {
        Market.Data storage market = Market.load(marketAddress);

        market.minLiquidityRatio = minLiquidityRatio;

        emit LogSetMinLiquidityRatio(marketAddress, minLiquidityRatio);
    }

    /// @dev Still need to support scenarios when updating market configuratinos
    /// and handle edge cases like locked markets
    function configureMarkets(MarketConfiguration.Data[] calldata marketConfigurations) external override onlyOwner {
        MarketManager.Data storage marketManager = MarketManager.load();
        marketManager.distributeDebtToVaults(address(0));

        uint256 totalMarketsWeight = 0;
        for (uint256 i = 0; i < marketConfigurations.length; i++) {
            marketManager.marketConfigurations[i] = marketConfigurations[i];
            totalMarketsWeight += marketConfigurations[i].weight;
        }
        marketManager.totalMarketsWeight = totalMarketsWeight.toUint128();
        marketManager.syncMarkets();

        emit LogConfigureMarkets(msg.sender, marketConfigurations);
    }
}
