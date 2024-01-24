// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { AccountNFT } from "@zaros/account-nft/AccountNFT.sol";
import { LiquidityEngine } from "@zaros/liquidity/LiquidityEngine.sol";
import { IPerpsEngine } from "@zaros/markets/perps/interfaces/IPerpsEngine.sol";
import { RewardDistributor } from "@zaros/reward-distributor/RewardDistributor.sol";
import { MockERC20 } from "./mocks/MockERC20.sol";
import { MockPriceFeed } from "./mocks/MockPriceFeed.sol";
import { MockUSDToken } from "./mocks/MockUSDToken.sol";
import { Constants } from "./utils/Constants.sol";
import { Events } from "./utils/Events.sol";
import { Storage } from "./utils/Storage.sol";
import { Users, MockPriceAdapters } from "./utils/Types.sol";

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

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    AccountNFT internal perpsAccountToken;
    MockERC20 internal mockWstEth;
    MockUSDToken internal usdToken;
    IPerpsEngine internal perpsEngine;
    IPerpsEngine internal perpsEngineImplementation;
    RewardDistributor internal rewardDistributor;
    LiquidityEngine internal liquidityEngine;

    /// @dev TODO: deploy real contracts instead of mocking them.
    address internal mockLiquidityEngineAddress = vm.addr({ privateKey: 0x02 });
    address internal mockRewardDistributorAddress = vm.addr({ privateKey: 0x03 });

    /// @dev TODO: think about forking tests
    MockPriceAdapters internal mockPriceAdapters;

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

        MockPriceFeed mockBtcUsdPriceAdapter = new MockPriceFeed(18, int256(MOCK_BTC_USD_PRICE));
        MockPriceFeed mockEthUsdPriceAdapter = new MockPriceFeed(18, int256(MOCK_ETH_USD_PRICE));
        MockPriceFeed mockUsdcUsdPriceAdapter = new MockPriceFeed(6, int256(MOCK_USDC_USD_PRICE));
        MockPriceFeed mockWstEthUsdPriceAdapter = new MockPriceFeed(18, int256(MOCK_WSTETH_USD_PRICE));

        mockPriceAdapters = MockPriceAdapters({
            mockBtcUsdPriceAdapter: mockBtcUsdPriceAdapter,
            mockEthUsdPriceAdapter: mockEthUsdPriceAdapter,
            mockUsdcUsdPriceAdapter: mockUsdcUsdPriceAdapter,
            mockWstEthUsdPriceAdapter: mockWstEthUsdPriceAdapter
        });

        address[] memory modules = deployModules();
        bytes4[][] memory modulesSelectors = getModulesSelectors();

        IDiamond.FacetCut[] memory facetCuts = getFacetCuts(modules, modulesSelectors);
        address[] memory initializables = new address[](1);

        address diamondCutModule = modules[0];
        address globalConfigurationModule = modules[2];

        initializables[0] = globalConfigurationModule;

        bytes memory diamondCutInitializeData = abi.encodeWithSelector(DiamondCutModule.initialize.selector, deployer);
        bytes memory perpsInitializeData = abi.encodeWithSelector(
            GlobalConfigurationModule.initialize.selector,
            address(perpsAccountToken),
            mockRewardDistributorAddress,
            address(usdToken),
            mockZarosAddress
        );

        bytes[] memory initializePayloads = new bytes[](1);
        initializePayloads[0] = diamondCutInitializeData;
        initializePayloads[1] = perpsInitializeData;

        IDiamond.InitParams memory initParams = IDiamond.InitParams({
            baseFacets: facetCuts,
            initializables: initializables,
            initializePayloads: initializePayloads
        });

        perpsEngine = IPerpsEngine(address(new Diamond(initParams)));

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

        perpsEngine.configureMarginCollateral(
            address(usdToken),
            USDZ_DEPOSIT_CAP,
            USDZ_LOAN_TO_VALUE,
            address(mockPriceAdapters.mockWstEthUsdPriceAdapter)
        );
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
