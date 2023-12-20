// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { IVerifierProxy } from "@zaros/external/chainlink/interfaces/IVerifierProxy.sol";
import { IFeeManager } from "@zaros/external/chainlink/interfaces/IFeeManager.sol";
import { AccountNFT } from "@zaros/account-nft/AccountNFT.sol";
import { LiquidityEngine } from "@zaros/liquidity/LiquidityEngine.sol";
import { PerpsEngine } from "@zaros/markets/perps/PerpsEngine.sol";
import { OrderFees } from "@zaros/markets/perps/storage/OrderFees.sol";
import { SettlementConfiguration } from "@zaros/markets/perps/storage/SettlementConfiguration.sol";
import { RewardDistributor } from "@zaros/reward-distributor/RewardDistributor.sol";
import { MockChainlinkFeeManager } from "./mocks/MockChainlinkFeeManager.sol";
import { MockChainlinkVerifier } from "./mocks/MockChainlinkVerifier.sol";
import { MockERC20 } from "./mocks/MockERC20.sol";
import { MockPriceFeed } from "./mocks/MockPriceFeed.sol";
import { MockUSDToken } from "./mocks/MockUSDToken.sol";
import { Constants } from "./utils/Constants.sol";
import { Events } from "./utils/Events.sol";
import { Storage } from "./utils/Storage.sol";
import { Users } from "./utils/Types.sol";

// Forge dependencies
import { Test } from "forge-std/Test.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";

// Open Zeppelin Upgradeable dependencies
import { ERC1967Proxy } from "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

// PRB Math dependencies
import { uMAX_UD60x18 } from "@prb-math/UD60x18.sol";

abstract contract Base_Test is Test, Constants, Events, Storage {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    Users internal users;
    address internal mockChainlinkForwarder = vm.addr({ privateKey: 0x01 });
    address internal mockChainlinkFeeManager;
    address internal mockChainlinkVerifier;

    /// @dev BTC / USD market configuration variables.
    SettlementConfiguration.DataStreamsMarketStrategy internal btcUsdMarketOrderStrategyData = SettlementConfiguration
        .DataStreamsMarketStrategy({
        chainlinkVerifier: IVerifierProxy(mockChainlinkVerifier),
        streamId: MOCK_ETH_USD_STREAM_ID,
        feedLabel: DATA_STREAMS_FEED_PARAM_KEY,
        queryLabel: DATA_STREAMS_TIME_PARAM_KEY,
        settlementDelay: ETH_USD_SETTLEMENT_DELAY,
        isPremium: false
    });
    SettlementConfiguration.Data internal btcUsdMarketOrderStrategy = SettlementConfiguration.Data({
        strategyType: SettlementConfiguration.StrategyType.DATA_STREAMS_MARKET,
        isEnabled: true,
        fee: DATA_STREAMS_SETTLEMENT_FEE,
        settlementStrategy: mockDefaultMarketOrderUpkeep,
        data: abi.encode(btcUsdMarketOrderStrategyData)
    });

    // TODO: update limit order strategy and move the market's strategies definition to a separate file.
    SettlementConfiguration.Data internal btcUsdLimitOrderStrategy = SettlementConfiguration.Data({
        strategyType: SettlementConfiguration.StrategyType.DATA_STREAMS_CUSTOM,
        isEnabled: true,
        fee: DATA_STREAMS_SETTLEMENT_FEE,
        settlementStrategy: mockDefaultMarketOrderUpkeep,
        data: abi.encode(btcUsdMarketOrderStrategyData)
    });
    SettlementConfiguration.Data[] internal btcUsdCustomTriggerStrategies;

    OrderFees.Data internal btcUsdOrderFees = OrderFees.Data({ makerFee: 0.04e18, takerFee: 0.08e18 });

    /// @dev ETH / USD market configuration variables.
    SettlementConfiguration.DataStreamsMarketStrategy internal ethUsdMarketOrderStrategyData = SettlementConfiguration
        .DataStreamsMarketStrategy({
        chainlinkVerifier: IVerifierProxy((mockChainlinkVerifier)),
        streamId: MOCK_ETH_USD_STREAM_ID,
        feedLabel: DATA_STREAMS_FEED_PARAM_KEY,
        queryLabel: DATA_STREAMS_TIME_PARAM_KEY,
        settlementDelay: ETH_USD_SETTLEMENT_DELAY,
        isPremium: false
    });
    SettlementConfiguration.Data internal ethUsdMarketOrderStrategy = SettlementConfiguration.Data({
        strategyType: SettlementConfiguration.StrategyType.DATA_STREAMS_MARKET,
        isEnabled: true,
        fee: DATA_STREAMS_SETTLEMENT_FEE,
        settlementStrategy: mockDefaultMarketOrderUpkeep,
        data: abi.encode(btcUsdMarketOrderStrategyData)
    });

    // TODO: update limit order strategy and move the market's strategies definition to a separate file.
    SettlementConfiguration.Data internal ethUsdLimitOrderStrategy = SettlementConfiguration.Data({
        strategyType: SettlementConfiguration.StrategyType.DATA_STREAMS_CUSTOM,
        isEnabled: true,
        fee: DATA_STREAMS_SETTLEMENT_FEE,
        settlementStrategy: mockDefaultMarketOrderUpkeep,
        data: abi.encode(ethUsdMarketOrderStrategyData)
    });
    SettlementConfiguration.Data[] internal ethUsdCustomTriggerStrategies;

    OrderFees.Data internal ethUsdOrderFees = OrderFees.Data({ makerFee: 0.04e18, takerFee: 0.08e18 });

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    AccountNFT internal perpsAccountToken;
    MockERC20 internal mockWstEth;
    MockUSDToken internal usdToken;
    PerpsEngine internal perpsEngine;
    PerpsEngine internal perpsEngineImplementation;
    RewardDistributor internal rewardDistributor;
    LiquidityEngine internal liquidityEngine;

    /// @dev TODO: deploy real contracts instead of mocking them.
    address internal mockLiquidityEngineAddress = vm.addr({ privateKey: 0x02 });
    address internal mockRewardDistributorAddress = vm.addr({ privateKey: 0x03 });

    /// @dev TODO: think about forking tests
    address internal mockDefaultMarketOrderSettlementStrategy = vm.addr({ privateKey: 0x04 });
    address internal mockDefaultMarketOrderUpkeep = vm.addr({ privateKey: 0x05 });
    MockPriceFeed internal mockUsdcUsdPriceFeed;
    MockPriceFeed internal mockWstEthUsdPriceFeed;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        users = Users({
            owner: createUser({ name: "Owner" }),
            naruto: createUser({ name: "Naruto Uzumaki" }),
            sasuke: createUser({ name: "Sasuke Uchiha" }),
            sakura: createUser({ name: "Sakura Haruno" }),
            madara: createUser({ name: "Madara Uchiha" })
        });
        vm.startPrank({ msgSender: users.owner });
        mockChainlinkFeeManager = address(new MockChainlinkFeeManager());
        mockChainlinkVerifier = address(new MockChainlinkVerifier(IFeeManager(mockChainlinkFeeManager)));

        ethUsdCustomTriggerStrategies.push(ethUsdLimitOrderStrategy);

        perpsAccountToken = new AccountNFT("Zaros Trading Accounts", "ZRS-TRADE-ACC", users.owner);
        usdToken = new MockUSDToken({ owner: users.owner, ownerBalance: 100_000_000e18 });
        mockWstEth = new MockERC20({
            name: "Wrapped Staked Ether",
            symbol: "wstETH",
            decimals_: 18,
            owner: users.owner,
            ownerBalance: 100_000_000e18
        });
        liquidityEngine = LiquidityEngine(mockLiquidityEngineAddress);
        rewardDistributor = RewardDistributor(mockRewardDistributorAddress);
        mockUsdcUsdPriceFeed = new MockPriceFeed(6, int256(MOCK_USDC_USD_PRICE));
        mockWstEthUsdPriceFeed = new MockPriceFeed(18, int256(MOCK_WSTETH_USD_PRICE));

        perpsEngineImplementation = new PerpsEngine();
        bytes memory initializeData = abi.encodeWithSelector(
            perpsEngineImplementation.initialize.selector,
            users.owner,
            mockChainlinkForwarder,
            mockChainlinkVerifier,
            address(perpsAccountToken),
            address(rewardDistributor),
            address(usdToken),
            address(liquidityEngine)
        );
        (bool success,) = address(perpsEngineImplementation).call(initializeData);
        require(success, "perpsEngineImplementation.initialize failed");

        perpsEngine =
            PerpsEngine(payable(address(new ERC1967Proxy(address(perpsEngineImplementation), initializeData))));

        configureContracts();

        vm.label({ account: address(perpsAccountToken), newLabel: "Perps Account NFT" });
        vm.label({ account: address(usdToken), newLabel: "Zaros USD" });
        vm.label({ account: address(liquidityEngine), newLabel: "Zaros" });
        vm.label({ account: address(rewardDistributor), newLabel: "Reward Distributor" });
        vm.label({ account: address(perpsEngine), newLabel: "Perps Engine" });

        approveContracts();
        changePrank({ msgSender: users.naruto });
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Generates a user, labels its address, and funds it with test assets.
    function createUser(string memory name) internal returns (address payable) {
        address payable user = payable(makeAddr(name));
        vm.deal({ account: user, newBalance: 100 ether });

        return user;
    }

    /// @dev Approves all Zaros contracts to spend the test assets.
    function approveContracts() internal {
        changePrank({ msgSender: users.naruto });
        usdToken.approve({ spender: address(perpsEngine), value: uMAX_UD60x18 });
        mockWstEth.approve({ spender: address(perpsEngine), value: uMAX_UD60x18 });

        changePrank({ msgSender: users.sasuke });
        usdToken.approve({ spender: address(perpsEngine), value: uMAX_UD60x18 });
        mockWstEth.approve({ spender: address(perpsEngine), value: uMAX_UD60x18 });

        changePrank({ msgSender: users.sakura });
        usdToken.approve({ spender: address(perpsEngine), value: uMAX_UD60x18 });
        mockWstEth.approve({ spender: address(perpsEngine), value: uMAX_UD60x18 });

        changePrank({ msgSender: users.madara });
        usdToken.approve({ spender: address(perpsEngine), value: uMAX_UD60x18 });
        mockWstEth.approve({ spender: address(perpsEngine), value: uMAX_UD60x18 });

        // Finally, change the active prank back to the Admin.
        changePrank({ msgSender: users.owner });
    }

    function configureContracts() internal {
        perpsAccountToken.transferOwnership(address(perpsEngine));

        usdToken.addToFeatureFlagAllowlist(MINT_FEATURE_FLAG, address(liquidityEngine));

        usdToken.addToFeatureFlagAllowlist(BURN_FEATURE_FLAG, address(liquidityEngine));

        usdToken.addToFeatureFlagAllowlist(MINT_FEATURE_FLAG, users.owner);

        usdToken.addToFeatureFlagAllowlist(BURN_FEATURE_FLAG, users.owner);

        perpsEngine.configureMarginCollateral(address(usdToken), USDZ_DEPOSIT_CAP, address(mockUsdcUsdPriceFeed));

        perpsEngine.configureMarginCollateral(address(mockWstEth), WSTETH_DEPOSIT_CAP, address(mockWstEthUsdPriceFeed));
    }

    // function distributeTokens() internal {
    //     deal({ token: address(usdToken), to: users.naruto, give: 1_000_000e18 });
    //     deal({ token: address(mockWstEth), to: users.naruto, give: 1_000_000e18 });

    //     deal({ token: address(usdToken), to: users.sasuke, give: 1_000_000e18 });
    //     deal({ token: address(mockWstEth), to: users.sasuke, give: 1_000_000e18 });

    //     deal({ token: address(usdToken), to: users.sakura, give: 1_000_000e18 });
    //     deal({ token: address(mockWstEth), to: users.sakura, give: 1_000_000e18 });

    //     deal({ token: address(usdToken), to: users.madara, give: 1_000_000e18 });
    //     deal({ token: address(mockWstEth), to: users.madara, give: 1_000_000e18 });
    // }

    /*//////////////////////////////////////////////////////////////////////////
                                    CALL EXPECTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Expects a call to {IERC20.transfer}.
    function expectCallToTransfer(IERC20 asset, address to, uint256 amount) internal {
        vm.expectCall({ callee: address(asset), data: abi.encodeCall(IERC20.transfer, (to, amount)) });
    }

    /// @dev Expects a call to {IERC20.transferFrom}.
    function expectCallToTransferFrom(IERC20 asset, address from, address to, uint256 amount) internal {
        vm.expectCall({ callee: address(asset), data: abi.encodeCall(IERC20.transferFrom, (from, to, amount)) });
    }
}
