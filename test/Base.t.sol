// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { AccountNFT } from "@zaros/account-nft/AccountNFT.sol";
import { IRootProxy } from "@zaros/tree-proxy/interfaces/IRootProxy.sol";
import { PerpsEngine } from "@zaros/perpetuals/PerpsEngine.sol";
import { IPerpsEngine } from "@zaros/perpetuals/interfaces/IPerpsEngine.sol";
import { MockERC20 } from "./mocks/MockERC20.sol";
import { MockPriceFeed } from "./mocks/MockPriceFeed.sol";
import { MockUSDToken } from "./mocks/MockUSDToken.sol";
import { Events } from "./utils/Events.sol";
import { Storage } from "./utils/Storage.sol";
import { Users, MockPriceAdapters } from "./utils/Types.sol";
import { ProtocolConfiguration } from "script/utils/ProtocolConfiguration.sol";
import {
    deployBranchs,
    getBranchsSelectors,
    getBranchUpgrades,
    getInitializables,
    getInitializePayloads
} from "script/helpers/TreeProxyHelpers.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";

// Open Zeppelin Upgradeable dependencies
import { ERC1967Proxy } from "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

// PRB Math dependencies
import { uMAX_UD60x18 } from "@prb-math/UD60x18.sol";

// PRB Test dependencies
import { PRBTest } from "prb-test/PRBTest.sol";

// Forge dependencies
import { StdCheats, StdUtils } from "forge-std/Test.sol";

abstract contract Base_Test is PRBTest, StdCheats, StdUtils, ProtocolConfiguration, Events, Storage {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    Users internal users;

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    AccountNFT internal perpsAccountToken;
    MockERC20 internal mockWstEth;
    MockUSDToken internal usdToken;
    IPerpsEngine internal perpsEngine;
    IPerpsEngine internal perpsEngineImplementation;

    /// @dev TODO: think about forking tests
    MockPriceAdapters internal mockPriceAdapters;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        users = Users({
            owner: createUser({ name: "Owner" }),
            settlementFeeReceiver: createUser({ name: "Settlement Fee Receiver" }),
            naruto: createUser({ name: "Naruto Uzumaki" }),
            sasuke: createUser({ name: "Sasuke Uchiha" }),
            sakura: createUser({ name: "Sakura Haruno" }),
            madara: createUser({ name: "Madara Uchiha" })
        });
        vm.startPrank({ msgSender: users.owner });

        perpsAccountToken = new AccountNFT("Zaros Trading Accounts", "ZRS-TRADE-ACC", users.owner);
        usdToken = new MockUSDToken({ owner: users.owner, deployerBalance: 100_000_000e18 });
        mockWstEth = new MockERC20({
            name: "Wrapped Staked Ether",
            symbol: "wstETH",
            decimals_: 18,
            deployerBalance: 100_000_000e18
        });

        MockPriceFeed mockBtcUsdPriceAdapter = new MockPriceFeed(18, int256(MOCK_BTC_USD_PRICE));
        MockPriceFeed mockEthUsdPriceAdapter = new MockPriceFeed(18, int256(MOCK_ETH_USD_PRICE));
        MockPriceFeed mockLinkUsdPriceAdapter = new MockPriceFeed(18, int256(MOCK_LINK_USD_PRICE));
        MockPriceFeed mockUsdcUsdPriceAdapter = new MockPriceFeed(6, int256(MOCK_USDC_USD_PRICE));
        MockPriceFeed mockWstEthUsdPriceAdapter = new MockPriceFeed(18, int256(MOCK_WSTETH_USD_PRICE));

        mockPriceAdapters = MockPriceAdapters({
            mockBtcUsdPriceAdapter: mockBtcUsdPriceAdapter,
            mockEthUsdPriceAdapter: mockEthUsdPriceAdapter,
            mockLinkUsdPriceAdapter: mockLinkUsdPriceAdapter,
            mockUsdcUsdPriceAdapter: mockUsdcUsdPriceAdapter,
            mockWstEthUsdPriceAdapter: mockWstEthUsdPriceAdapter
        });

        bool isTestnet = false;
        address accessKeyManager = address(0);
        address[] memory branches = deployBranchs(isTestnet);
        bytes4[][] memory branchesSelectors = getBranchsSelectors(isTestnet);
        IRootProxy.BranchUpgrade[] memory branchUpgrades =
            getBranchUpgrades(branches, branchesSelectors, IRootProxy.BranchUpgradeAction.Add);
        address[] memory initializables = getInitializables(branches, isTestnet);
        bytes[] memory initializePayloads = getInitializePayloads(
            users.owner, address(perpsAccountToken), address(usdToken), accessKeyManager, isTestnet
        );

        IRootProxy.InitParams memory initParams = IRootProxy.InitParams({
            initBranches: branchUpgrades,
            initializables: initializables,
            initializePayloads: initializePayloads
        });
        perpsEngine = IPerpsEngine(address(new PerpsEngine(initParams)));

        configureContracts();

        vm.label({ account: address(perpsAccountToken), newLabel: "Perps Account NFT" });
        vm.label({ account: address(usdToken), newLabel: "Zaros USD" });
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

        // TODO: Temporary, switch to liquidity engine
        usdToken.addToFeatureFlagAllowlist(MINT_FEATURE_FLAG, address(perpsEngine));

        perpsEngine.configureMarginCollateral(
            address(usdToken),
            USDZ_DEPOSIT_CAP,
            USDZ_LOAN_TO_VALUE,
            address(mockPriceAdapters.mockUsdcUsdPriceAdapter)
        );
        perpsEngine.configureMarginCollateral(
            address(mockWstEth),
            WSTETH_DEPOSIT_CAP,
            WSTETH_LOAN_TO_VALUE,
            address(mockPriceAdapters.mockWstEthUsdPriceAdapter)
        );
    }

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
