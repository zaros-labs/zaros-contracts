// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { MarketMakingEngineConfiguration } from "@zaros/market-making/leaves/MarketMakingEngineConfiguration.sol";
import { Vault } from "@zaros/market-making/leaves/Vault.sol";
import { MarketDebt } from "src/market-making/leaves/MarketDebt.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { SwapStrategy } from "@zaros/market-making/leaves/SwapStrategy.sol";

// Open Zeppelin Upgradeable dependencies
import { Initializable } from "@openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";

contract MarketMakingEngineConfigurationBranch is Initializable, OwnableUpgradeable {
    using MarketMakingEngineConfiguration for MarketMakingEngineConfiguration.Data;

    constructor() {
        _disableInitializers();
    }

    /// @notice Emitted when a new vault is created.
    /// @param sender The address that created the vault.
    /// @param vaultId The vault id.
    event LogCreateVault(address indexed sender, uint128 vaultId);

    /// @notice Emitted when a vault is updated.
    /// @param sender The address that updated the vault.
    /// @param vaultId The vault id.
    event LogUpdateVaultConfiguration(address indexed sender, uint128 vaultId);

    /// @notice Emmited when percentages are set for a market and it's feeRecipients.
    /// @param marketId The perps engine's market id.
    /// @param marketRatioPercentage the percentage of accumulated weth allocated for market.
    /// @param feeRecipientsPercentage the percentage of accumulated weth allocated for feeRecipients.
    event LogSetPercentageRatio(uint128 indexed marketId, uint128 marketRatioPercentage, uint128 feeRecipientsPercentage);

    /// @dev The Ownable contract is initialized at the UpgradeBranch.
    /// @dev {MarketMakingEngineConfigurationBranch} UUPS initializer.
    function initialize(address usdz, address perpsEngine, address owner) external initializer {
        __Ownable_init(owner);
        MarketMakingEngineConfiguration.Data storage marketMakingEngineConfiguration =
            MarketMakingEngineConfiguration.load();

        marketMakingEngineConfiguration.usdz = usdz;
        marketMakingEngineConfiguration.perpsEngine = perpsEngine;
    }

    /// @notice Returns the address of custom referral code
    /// @param customReferralCode The custom referral code.
    /// @return referrer The address of the referrer.
    function getCustomReferralCodeReferrer(string memory customReferralCode) external view returns (address) { }

    /// @dev Invariants involved in the call:
    /// TODO: add invariants
    function configureSystemParameters() external onlyOwner { }

    /// @dev Invariants involved in the call:
    /// TODO: add invariants
    function configureSequencerUptimeFeed() external onlyOwner { }

    /// @dev Invariants involved in the call:
    /// TODO: add invariants
    function createCustomReferralCode() external onlyOwner { }

    /// @dev Invariants involved in the call:
    /// Must NOT be able to create a vault with id set to 0
    function createVault(Vault.CreateParams calldata params) external onlyOwner {
        if (params.indexToken == address(0)) {
            revert Errors.ZeroInput("indexToken");
        }

        if (params.depositCap == 0) {
            revert Errors.ZeroInput("depositCap");
        }

        if (params.withdrawalDelay == 0) {
            revert Errors.ZeroInput("withdrawDelay");
        }

        if (params.vaultId == 0) {
            revert Errors.ZeroInput("vaultId");
        }

        Vault.create(params);

        emit LogCreateVault(msg.sender, params.vaultId);
    }

    /// @dev Invariants involved in the call:
    /// Must NOT be able to update vault with id set to 0
    function updateVaultConfiguration(Vault.UpdateParams calldata params) external onlyOwner {
        if (params.depositCap == 0) {
            revert Errors.ZeroInput("depositCap");
        }

        if (params.withdrawalDelay == 0) {
            revert Errors.ZeroInput("withdrawDelay");
        }

        if (params.vaultId == 0) {
            revert Errors.ZeroInput("vaultId");
        }

        Vault.update(params);

        emit LogUpdateVaultConfiguration(msg.sender, params.vaultId);
    }

    /// @notice Sets the percentage ratio between fee recipients and market.
    /// @dev Percentage is represented in BPS, requires the sum to equal 10_000 (100%).
    /// @param marketId The market where percentage ratio will be set.
    /// @param feeRecipientsPercentage The percentage that will be received by fee recipients.
    /// from the total accumulated weth.
    /// @param marketPercentage The percentage that will be received by the market.
    /// from the total accumulated weth.
    function setPercentageRatio(
        uint128 marketId, 
        uint128 marketPercentage,
        uint128 feeRecipientsPercentage
    ) 
        external 
        onlyOwner 
    {
        if(feeRecipientsPercentage + marketPercentage != SwapStrategy.BPS_DENOMINATOR) 
            revert Errors.PercentageValidationFailed();

        MarketDebt.Data storage marketDebtData = MarketDebt.load(marketId);

        marketDebtData.collectedFees.feeRecipientsPercentage = feeRecipientsPercentage;
        marketDebtData.collectedFees.marketPercentage = marketPercentage;

        emit LogSetPercentageRatio(marketId, marketPercentage, feeRecipientsPercentage);
    }

    /// @notice Returns the set percentages. 
    /// @param marketId The market where percentage ratio has been set.
    /// @return marketPercentage The percentage allocated for the market.
    /// @return feeRecipientsPercentage The percentage allocated for fee recipients.
    function getPercentageRatio(
        uint128 marketId
    ) 
        external 
        view 
        returns (uint128 marketPercentage, uint128 feeRecipientsPercentage)
    {
        MarketDebt.Data storage marketDebtData = MarketDebt.load(marketId);                 
       
        return (marketDebtData.collectedFees.marketPercentage, marketDebtData.collectedFees.feeRecipientsPercentage);
    }
}
