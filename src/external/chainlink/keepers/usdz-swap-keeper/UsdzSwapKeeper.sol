// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { ILogAutomation, Log as AutomationLog } from "@zaros/external/chainlink/interfaces/ILogAutomation.sol";
import { BaseKeeper } from "../BaseKeeper.sol";
import { IMarketMakingEngine } from "@zaros/market-making/MarketMakingEngine.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { UsdTokenSwap } from "@zaros/market-making/leaves/UsdTokenSwap.sol";

// TODO: Make it a log trigger, streams compatible, automation keeper
contract UsdTokenSwapKeeper is ILogAutomation, BaseKeeper { // @note this address goes in contract to automate
    bytes32 internal constant USDZ_SWAP_KEEPER_LOCATION = keccak256(
        abi.encode(uint256(keccak256("fi.zaros.external.chainlink.keepers.UsdTokenSwapKeeper")) - 1)
    ) & ~bytes32(uint256(0xff));

    /// @custom:storage-location erc7201:fi.zaros.external.chainlink.UsdTokenSwapKeeper
    /// @param marketMakingEngine The address of the MarketMakingEngine contract.
    struct UsdTokenSwapKeeperStorage {
        IMarketMakingEngine marketMakingEngine;
    }

    constructor() {
        _disableInitializers();
    }

    /// @notice {UsdzSwapKeeper} UUPS initializer.
    function initialize(address owner, address marketMakingEngine) external initializer {
        __BaseKeeper_init(owner);

        if (address(marketMakingEngine) == address(0)) {
            revert Errors.ZeroInput("marketMakingEngine");
        }

        UsdTokenSwapKeeperStorage storage self = _getUsdTokenSwapKeeperStorage();
        self.marketMakingEngine = IMarketMakingEngine(marketMakingEngine);
    }

    function getConfig() external view returns (address keeperOwner, address marketMakingEngine) {
        UsdTokenSwapKeeperStorage storage self = _getUsdTokenSwapKeeperStorage();

        keeperOwner = owner();
        marketMakingEngine = address(self.marketMakingEngine);
    }

    function checkLog(
        AutomationLog calldata log,
        bytes memory checkData
    )
        external
        view
        returns (bool upkeepNeeded, bytes memory performData)
    {
        // https://docs.chain.link/chainlink-automation/guides/log-trigger
        // 0th index is the event signature hash
        address caller = bytes32ToAddress(log.topics[1]);
        uint128 requestId = uint128(uint256(log.topics[2]));

        // load swap data
        UsdTokenSwap.Data storage tokenSwapData = UsdTokenSwap.load();

        // load requiest for user by id
        UsdTokenSwap.SwapRequest storage request = tokenSwapData.swapRequests[caller][requestId];

        // encode perform data
        performData = abi.encode(caller, requestId);

        // set upkeepneeded depending if request is processed
        upkeepNeeded = !request.processed;
    }

    function performUpkeep(bytes calldata peformData) external override onlyForwarder {
        // the mm engine must have access to the ZLP Vault assets, i.e approval to spend tokens from each ZLP Vault's
        // address. This is needed when settling vaults debt for usdc to pay for accumulated unsettled debt. In the
        // same way that the mm engine can also send assets to each ZLP Vault to realize accumulated net credit, thus
        // updating the conversion rate.

        (address user, uint128 requestId) = abi.decode(peformData, (address, uint128));
        UsdTokenSwapKeeperStorage storage self = _getUsdTokenSwapKeeperStorage();

        self.marketMakingEngine.fulfillSwap(user, requestId);
    }

    function setConfig(address marketMakingEngine) external onlyOwner {
        if (marketMakingEngine == address(0)) {
            revert Errors.ZeroInput("marketMakingEngine");
        }

        UsdTokenSwapKeeperStorage storage self = _getUsdTokenSwapKeeperStorage();

        self.marketMakingEngine = IMarketMakingEngine(marketMakingEngine);
    }

    function _getUsdTokenSwapKeeperStorage() internal pure returns (UsdTokenSwapKeeperStorage storage self) {
        bytes32 slot = USDZ_SWAP_KEEPER_LOCATION;

        assembly {
            self.slot := slot
        }
    }

    function bytes32ToAddress(bytes32 _address) public pure returns (address) {
        return address(uint160(uint256(_address)));
    }
}
