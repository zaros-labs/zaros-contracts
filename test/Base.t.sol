// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { AccountNFT } from "@zaros/account-nft/AccountNFT.sol";
import { Zaros } from "@zaros/core/Zaros.sol";
import { PerpsEngine } from "@zaros/markets/perps/PerpsEngine.sol";
import { RewardDistributor } from "@zaros/reward-distributor/RewardDistributor.sol";
import { Constants } from "@zaros/utils/Constants.sol";
import { MockZarosUSD } from "./mocks/MockZarosUSD.sol";
import { Events } from "./utils/Events.sol";
import { Users } from "./utils/Types.sol";

// Forge dependencies
import { Test } from "forge-std/Test.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";

// Open Zeppelin Upgradeable dependencies
import { ERC1967Proxy } from "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

// PRB Math dependencies
import { uMAX_UD60x18 } from "@prb-math/UD60x18.sol";

abstract contract Base_Test is Test, Events {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    Users internal users;

    /// @dev TODO: deploy real contracts instead of mocking them
    address internal mockZarosAddress = vm.addr({ privateKey: 0x02 });
    address internal mockRewardDistributorAddress = vm.addr({ privateKey: 0x03 });
    address internal mockChainlinkVerifier = vm.addr({ privateKey: 0x04 });
    /// @dev TODO: mock a real price feed
    address internal mockUsdcUsdPriceFeed = vm.addr({ privateKey: 0x05 });

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    AccountNFT internal perpsAccountToken;
    MockZarosUSD internal usdToken;
    PerpsEngine internal perpsEngine;
    PerpsEngine internal perpsEngineImplementation;
    RewardDistributor internal rewardDistributor;
    Zaros internal zaros;

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
        zaros = Zaros(mockZarosAddress);
        rewardDistributor = RewardDistributor(mockRewardDistributorAddress);

        perpsEngineImplementation = new PerpsEngine();
        bytes memory initializeData = abi.encodeWithSelector(
            perpsEngineImplementation.initialize.selector,
            mockChainlinkVerifier,
            address(perpsAccountToken),
            address(rewardDistributor),
            address(usdToken),
            address(zaros)
        );
        (bool success,) = address(perpsEngineImplementation).call(initializeData);
        require(success, "perpsEngineImplementation.initialize failed");

        perpsEngine = PerpsEngine(address(new ERC1967Proxy(address(perpsEngineImplementation), initializeData)));

        distributeTokens();
        configureContracts();

        vm.label({ account: address(perpsAccountToken), newLabel: "Perps Account NFT" });
        vm.label({ account: address(usdToken), newLabel: "Zaros USD" });
        vm.label({ account: address(zaros), newLabel: "Zaros" });
        vm.label({ account: address(rewardDistributor), newLabel: "Reward Distributor" });
        vm.label({ account: address(perpsEngine), newLabel: "Perps Manager" });
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

        changePrank({ msgSender: users.sasuke });
        usdToken.approve({ spender: address(perpsEngine), amount: uMAX_UD60x18 });

        changePrank({ msgSender: users.sakura });
        usdToken.approve({ spender: address(perpsEngine), amount: uMAX_UD60x18 });

        changePrank({ msgSender: users.madara });
        usdToken.approve({ spender: address(perpsEngine), amount: uMAX_UD60x18 });

        // Finally, change the active prank back to the Admin.
        changePrank({ msgSender: users.owner });
    }

    function configureContracts() internal {
        perpsAccountToken.transferOwnership(address(perpsEngine));

        usdToken.addToFeatureFlagAllowlist(Constants.MINT_FEATURE_FLAG, address(zaros));

        usdToken.addToFeatureFlagAllowlist(Constants.BURN_FEATURE_FLAG, address(zaros));

        usdToken.addToFeatureFlagAllowlist(Constants.MINT_FEATURE_FLAG, users.owner);

        usdToken.addToFeatureFlagAllowlist(Constants.BURN_FEATURE_FLAG, users.owner);

        perpsEngine.setIsCollateralEnabled(address(usdToken), true);

        perpsEngine.configurePriceFeed(address(usdToken), mockUsdcUsdPriceFeed);
    }

    function distributeTokens() internal {
        deal({ token: address(usdToken), to: users.naruto, give: 1_000_000e18 });

        deal({ token: address(usdToken), to: users.sasuke, give: 1_000_000e18 });

        deal({ token: address(usdToken), to: users.sakura, give: 1_000_000e18 });

        deal({ token: address(usdToken), to: users.madara, give: 1_000_000e18 });
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
