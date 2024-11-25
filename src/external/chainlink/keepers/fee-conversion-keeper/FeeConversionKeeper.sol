// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { DexSwapStrategy } from "@zaros/market-making/leaves/DexSwapStrategy.sol";
import { Market } from "src/market-making/leaves/Market.sol";
import { IAutomationCompatible } from "@zaros/external/chainlink/interfaces/IAutomationCompatible.sol";
import { BaseKeeper } from "../BaseKeeper.sol";
import { IMarketMakingEngine } from "@zaros/market-making/MarketMakingEngine.sol";
import { Errors } from "@zaros/utils/Errors.sol";

// Open Zeppelin dependencies
import { EnumerableMap } from "@openzeppelin/utils/structs/EnumerableMap.sol";

// TODO: Make it a custom trigger, automation keeper
contract FeeConversionKeeper is IAutomationCompatible, BaseKeeper {
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    /// @notice ERC7201 storage location.
    bytes32 internal constant FEE_CONVERSION_KEEPER_LOCATION = keccak256(
        abi.encode(uint256(keccak256("fi.zaros.external.chainlink.keepers.FeeConversionKeeper")) - 1)
    ) & ~bytes32(uint256(0xff));

    /// @custom:storage-location erc7201:fi.zaros.external.chainlink.FeeConversionKeeper
    /// @param marketMakingEngine The address of the MarketMakingEngine contract.
    struct FeeConversionKeeperStorage {
        IMarketMakingEngine marketMakingEngine;
        uint128 dexSwapStrategyId;
        uint128 minFeeDistributionValueUsd;
    }

    constructor() {
        _disableInitializers();
    }

    /// @notice {LiquidationKeeper} UUPS initializer.
    function initialize(
        address owner,
        IMarketMakingEngine marketMakingEngine,
        uint128 dexSwapStrategyId,
        uint128 minFeeDistributionValueUsd
    )
        external
        initializer
    {
        __BaseKeeper_init(owner);

        if (address(marketMakingEngine) == address(0)) {
            revert Errors.ZeroInput("marketMakingEngine");
        }

        DexSwapStrategy.Data storage dexSwapStrategy = DexSwapStrategy.load(dexSwapStrategyId);

        // reverts if the dex swap strategy has an invalid dex adapter
        if (dexSwapStrategy.dexAdapter == address(0)) {
            revert Errors.DexSwapStrategyHasAnInvalidDexAdapter(dexSwapStrategyId);
        }

        if (minFeeDistributionValueUsd == 0) {
            revert Errors.ZeroInput("minFeeDistributionValueUsd");
        }

        FeeConversionKeeperStorage storage self = _getFeeConversionKeeperStorage();

        self.marketMakingEngine = marketMakingEngine;
        self.dexSwapStrategyId = dexSwapStrategyId;
        self.minFeeDistributionValueUsd = minFeeDistributionValueUsd;
    }

    function checkUpkeep(bytes calldata checkData)
        external
        view
        returns (bool upkeepNeeded, bytes memory performData)
    {
        FeeConversionKeeperStorage memory self = _getFeeConversionKeeperStorage();

        uint128[] memory liveMarketIds = self.marketMakingEngine.getLiveMarketIds();

        bool distributionNeeded;
        uint128[] memory marketIds;
        address[] memory assets;
        uint256 index;
        uint128 marketId;

        // Iterate over markets by id
        for (uint128 i; i < liveMarketIds.length; i++) {
            marketId = liveMarketIds[i];

            Market.Data storage market = Market.loadExisting(marketId);

            EnumerableMap.AddressToUintMap storage receivedMarketFees = market.receivedMarketFees;

            // Iterate over receivedMarketFees
            for (uint128 j; j < receivedMarketFees.length(); j++) {
                (address asset, uint256 collectedFee) = receivedMarketFees.at(j);

                distributionNeeded = checkFeeDistributionNeeded(asset, collectedFee);

                if (distributionNeeded) {
                    // set upkeepNeeded = true
                    upkeepNeeded = true;

                    // set marketId, asset
                    marketIds[index] = (marketId);
                    assets[index] = asset;

                    index++;
                }
            }
        }

        if (upkeepNeeded) {
            performData = abi.encode(marketIds, assets);
        }
    }

    // call FeeDistributionBranch::convertAccumulatedFeesToWeth
    function performUpkeep(bytes calldata performData) external override onlyForwarder {
        FeeConversionKeeperStorage memory self = _getFeeConversionKeeperStorage();

        IMarketMakingEngine marketMakingEngine = self.marketMakingEngine;

        // decode performData
        (uint128[] memory marketIds, address[] memory assets) = abi.decode(performData, (uint128[], address[]));

        for (uint256 i = 0; i < marketIds.length; i++) {
            marketMakingEngine.convertAccumulatedFeesToWeth(marketIds[i], assets[i], self.dexSwapStrategyId, "");
        }
    }

    function getConfig() external view returns (address keeperOwner, address marketMakingEngine) {
        FeeConversionKeeperStorage storage self = _getFeeConversionKeeperStorage();

        keeperOwner = owner();
        marketMakingEngine = address(self.marketMakingEngine);
    }

    function setConfig(address marketMakingEngine, uint128 minFeeDistributionValueUsd) external onlyOwner {
        if (marketMakingEngine == address(0)) {
            revert Errors.ZeroInput("perpsEmarketMakingEnginengine");
        }

        if (minFeeDistributionValueUsd == 0) {
            revert Errors.ZeroInput("minFeeDistributionValueUsd");
        }

        FeeConversionKeeperStorage storage self = _getFeeConversionKeeperStorage();

        self.marketMakingEngine = IMarketMakingEngine(marketMakingEngine);
        self.minFeeDistributionValueUsd = minFeeDistributionValueUsd;
    }

    function _getFeeConversionKeeperStorage() internal pure returns (FeeConversionKeeperStorage storage self) {
        bytes32 slot = FEE_CONVERSION_KEEPER_LOCATION;

        assembly {
            self.slot := slot
        }
    }

    function checkFeeDistributionNeeded(
        address asset,
        uint256 collectedFee
    )
        internal
        view
        returns (bool distributionNeeded)
    {
        FeeConversionKeeperStorage storage self = _getFeeConversionKeeperStorage();

        uint256 assetValue = self.marketMakingEngine.getAssetValue(asset, collectedFee);

        distributionNeeded = assetValue > self.minFeeDistributionValueUsd;
    }
}
