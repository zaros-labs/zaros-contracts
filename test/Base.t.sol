// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { AccountNFT } from "@zaros/account-nft/AccountNFT.sol";
import { Zaros } from "@zaros/core/Zaros.sol";
import { PerpsEngine } from "@zaros/markets/perps/PerpsEngine.sol";
import { OrderFees } from "@zaros/markets/perps/storage/OrderFees.sol";
import { RewardDistributor } from "@zaros/reward-distributor/RewardDistributor.sol";
import { MockERC20 } from "./mocks/MockERC20.sol";
import { MockPriceFeed } from "./mocks/MockPriceFeed.sol";
import { MockZarosUSD } from "./mocks/MockZarosUSD.sol";
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
    address internal mockChainlinkVerifier = vm.addr({ privateKey: 0x02 });
    uint128 internal constant ETH_USD_MARKET_ID = 1;
    string internal constant ETH_USD_MARKET_NAME = "ETH/USD Perpetual Futures";
    string internal constant ETH_USD_MARKET_SYMBOL = "ETH/USD PERP";
    bytes32 internal constant mockEthUsdStreamId = keccak256(bytes("mockEthUsdStreamId"));
    uint128 internal constant ETH_USD_MMR = 0.01e18;
    uint128 internal constant ETH_USD_MAX_OI = 100_000_000e18;
    uint128 internal constant ETH_USD_MIN_IMR = 0.01e18;
    uint256 internal constant MOCK_ETH_USD_PRICE = 1000e18;
    uint256 internal constant MOCK_USDC_USD_PRICE = 1e6;
    uint256 internal constant MOCK_WSTETH_USD_PRICE = 2000e18;
    OrderFees.Data public orderFees = OrderFees.Data({ makerFee: 0.04e18, takerFee: 0.08e18 });

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    AccountNFT internal perpsAccountToken;
    MockERC20 internal mockWstEth;
    MockZarosUSD internal usdToken;
    PerpsEngine internal perpsEngine;
    PerpsEngine internal perpsEngineImplementation;
    RewardDistributor internal rewardDistributor;
    Zaros internal zaros;
    /// @dev TODO: think about forking tests
    MockPriceFeed internal mockEthUsdPriceFeed;
    MockPriceFeed internal mockUsdcUsdPriceFeed;
    MockPriceFeed internal mockWstEthUsdPriceFeed;

    /// @dev TODO: deploy real contracts instead of mocking them.
    address internal mockZarosAddress = vm.addr({ privateKey: 0x03 });
    address internal mockRewardDistributorAddress = vm.addr({ privateKey: 0x04 });

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

        perpsAccountToken = new AccountNFT("Zaros Trading Accounts", "ZRS-TRADE-ACC");
        usdToken = new MockZarosUSD({ ownerBalance: 100_000_000e18 });
        mockWstEth =
        new MockERC20({ name: "Wrapped Staked Ether", symbol: "wstETH", decimals_: 18, ownerBalance: 100_000_000e18 });
        zaros = Zaros(mockZarosAddress);
        rewardDistributor = RewardDistributor(mockRewardDistributorAddress);
        mockUsdcUsdPriceFeed = new MockPriceFeed(6, int256(MOCK_USDC_USD_PRICE));
        mockEthUsdPriceFeed = new MockPriceFeed(18, int256(MOCK_ETH_USD_PRICE));
        mockWstEthUsdPriceFeed = new MockPriceFeed(18, int256(MOCK_WSTETH_USD_PRICE));

        perpsEngineImplementation = new PerpsEngine();
        bytes memory initializeData = abi.encodeWithSelector(
            perpsEngineImplementation.initialize.selector,
            mockChainlinkForwarder,
            mockChainlinkVerifier,
            address(perpsAccountToken),
            address(rewardDistributor),
            address(usdToken),
            address(zaros)
        );
        (bool success,) = address(perpsEngineImplementation).call(initializeData);
        require(success, "perpsEngineImplementation.initialize failed");

        perpsEngine =
            PerpsEngine(payable(address(new ERC1967Proxy(address(perpsEngineImplementation), initializeData))));

        configureContracts();

        vm.label({ account: address(perpsAccountToken), newLabel: "Perps Account NFT" });
        vm.label({ account: address(usdToken), newLabel: "Zaros USD" });
        vm.label({ account: address(zaros), newLabel: "Zaros" });
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
        usdToken.approve({ spender: address(perpsEngine), amount: uMAX_UD60x18 });
        mockWstEth.approve({ spender: address(perpsEngine), amount: uMAX_UD60x18 });

        changePrank({ msgSender: users.sasuke });
        usdToken.approve({ spender: address(perpsEngine), amount: uMAX_UD60x18 });
        mockWstEth.approve({ spender: address(perpsEngine), amount: uMAX_UD60x18 });

        changePrank({ msgSender: users.sakura });
        usdToken.approve({ spender: address(perpsEngine), amount: uMAX_UD60x18 });
        mockWstEth.approve({ spender: address(perpsEngine), amount: uMAX_UD60x18 });

        changePrank({ msgSender: users.madara });
        usdToken.approve({ spender: address(perpsEngine), amount: uMAX_UD60x18 });
        mockWstEth.approve({ spender: address(perpsEngine), amount: uMAX_UD60x18 });

        // Finally, change the active prank back to the Admin.
        changePrank({ msgSender: users.owner });
    }

    function configureContracts() internal {
        perpsAccountToken.transferOwnership(address(perpsEngine));

        usdToken.addToFeatureFlagAllowlist(MINT_FEATURE_FLAG, address(zaros));

        usdToken.addToFeatureFlagAllowlist(BURN_FEATURE_FLAG, address(zaros));

        usdToken.addToFeatureFlagAllowlist(MINT_FEATURE_FLAG, users.owner);

        usdToken.addToFeatureFlagAllowlist(BURN_FEATURE_FLAG, users.owner);

        perpsEngine.configureCollateral(address(usdToken), type(uint256).max);

        perpsEngine.configureCollateral(address(mockWstEth), type(uint256).max);

        perpsEngine.configurePriceFeed(address(usdToken), address(mockUsdcUsdPriceFeed));

        perpsEngine.configurePriceFeed(address(mockWstEth), address(mockWstEthUsdPriceFeed));
    }

    function createMarkets() internal {
        perpsEngine.createPerpsMarket(
            ETH_USD_MARKET_ID,
            ETH_USD_MARKET_NAME,
            ETH_USD_MARKET_SYMBOL,
            mockEthUsdStreamId,
            address(mockEthUsdPriceFeed),
            ETH_USD_MMR,
            ETH_USD_MAX_OI,
            ETH_USD_MIN_IMR,
            orderFees
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
