// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { MockERC20 } from "test/mocks/MockERC20.sol";
import { MockPriceFeed } from "test/mocks/MockPriceFeed.sol";
import { MockZarosUSD } from "test/mocks/MockZarosUSD.sol";
import { Constants } from "@zaros/utils/Constants.sol";
import { AccountNFT } from "@zaros/account-nft/AccountNFT.sol";
import { Zaros } from "@zaros/core/Zaros.sol";
import { RewardDistributor } from "@zaros/reward-distributor/RewardDistributor.sol";
import { CollateralConfig } from "@zaros/core/storage/CollateralConfig.sol";

// Forge dependencies
import { Test } from "forge-std/Test.sol";

contract ZarosForkingTest is Test {
    /// @dev Contract addresses
    address internal deployer;
    MockERC20 internal sFrxEth;
    MockERC20 internal usdc;
    MockZarosUSD internal zrsUsd;
    AccountNFT internal accountNft;
    Zaros internal zaros;
    uint256 internal goerliFork;

    /// @dev Configuration constants
    uint80 public constant SFRXETH_ISSUANCE_RATIO = 200e18;
    uint80 public constant SFRXETH_LIQUIDATION_RATIO = 150e18;
    uint256 public constant SFRXETH_MIN_DELEGATION = 0.5e18;
    uint256 public constant SFRXETH_DEPOSIT_CAP = 100_000e18;
    uint80 public constant USDC_ISSUANCE_RATIO = 150e18;
    uint80 public constant USDC_LIQUIDATION_RATIO = 110e18;
    uint256 public constant USDC_MIN_DELEGATION = 1000e18;
    uint256 public constant USDC_DEPOSIT_CAP = 100_000_000e6;
    uint80 public constant LIQUIDATION_REWARD_RATIO = 0.05e18;
    address public ethUsdOracle;
    address public usdcUsdOracle;

    function setUp() public {
        deployer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
        goerliFork = vm.createFork(vm.envString("GOERLI_RPC_URL"));
        vm.selectFork(goerliFork);
        startHoax(deployer);

        sFrxEth = MockERC20(vm.envAddress("SFRXETH"));
        usdc = MockERC20(vm.envAddress("USDC"));
        zrsUsd = MockZarosUSD(vm.envAddress("ZRSUSD"));
        accountNft = AccountNFT(vm.envAddress("ACCOUNT_NFT"));
        zaros = Zaros(vm.envAddress("ZAROS"));
        ethUsdOracle = vm.envAddress("ETH_USD_ORACLE");
        usdcUsdOracle = vm.envAddress("USDC_USD_ORACLE");
    }

    function test_Forking_LpsCanDepositAndWithdraw() public {
        uint256 amount = 5e18;
        sFrxEth.approve(address(zaros), type(uint256).max);
        _createAccountDepositAndDelegate(address(sFrxEth), amount);
        // get account id of the user's first created account
        // TODO: improve handling account id query
        uint128 accountId = uint128(accountNft.tokenOfOwnerByIndex(deployer, 0));
        _undelegateAndWithdraw(accountId, address(sFrxEth), amount);
    }

    function _createAccountDepositAndDelegate(address collateralType, uint256 amount) internal {
        bytes memory depositData = abi.encodeWithSelector(zaros.deposit.selector, collateralType, amount);
        bytes memory delegateCollateralData =
            abi.encodeWithSelector(zaros.delegateCollateral.selector, collateralType, amount);
        bytes[] memory data = new bytes[](2);
        data[0] = depositData;
        data[1] = delegateCollateralData;

        // Creates a new Zaros account and calls `deposit` and `delegateCollateral` in the same transaction
        zaros.createAccountAndMulticall(data);
        (uint256 positionCollateral,) = zaros.getPositionCollateral(uint128(1), collateralType);
    }

    function _undelegateAndWithdraw(uint128 accountId, address collateralType, uint256 amount) internal {
        (uint256 positionCollateralAmount,) = zaros.getPositionCollateral(accountId, collateralType);
        uint256 newAmount = positionCollateralAmount - amount;
        bytes memory delegateCollateralData =
            abi.encodeWithSelector(zaros.delegateCollateral.selector, accountId, collateralType, newAmount);
        bytes memory withdrawData = abi.encodeWithSelector(zaros.withdraw.selector, accountId, collateralType, amount);
        bytes[] memory data = new bytes[](2);
        data[0] = delegateCollateralData;
        data[1] = withdrawData;

        (uint256 collateralBefore,) = zaros.getPositionCollateral(accountId, collateralType);

        // Undelegates and withdraws the given amount of sFrxEth
        zaros.multicall(data);
        (uint256 collateralAfter,) = zaros.getPositionCollateral(accountId, collateralType);
    }
}
