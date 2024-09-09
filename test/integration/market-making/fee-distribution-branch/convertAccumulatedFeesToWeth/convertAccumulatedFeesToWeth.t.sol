// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { MockUniswapRouter } from "test/mocks/MockUniswapRouter.sol";
import { Vault } from "@zaros/market-making/leaves/Vault.sol";
import { Collateral } from "@zaros/market-making/leaves/Collateral.sol";
import { FeeDistributionBranch } from "@zaros/market-making/branches/FeeDistributionBranch.sol";
import { MockPriceFeed } from "test/mocks/MockPriceFeed.sol";
import "forge-std/console.sol";

// Openzeppelin dependencies
import { IERC20, IERC20Metadata, IERC4626, SafeERC20 } from "@openzeppelin/token/ERC20/extensions/ERC4626.sol";
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";

// UniSwap dependencies
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

contract MarketMaking_FeeDistribution_convertAccumulatedFeesToWeth is Base_Test {
    using EnumerableSet for EnumerableSet.UintSet;

    // contract address
    address thisContractAddr = 0xD30116ac9525d7335D7C731a9FBf4624975e9b20;

    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVault();
        changePrank({ msgSender: address(perpsEngine) });

        // set vault collateral types
        Vault.Data storage vault = Vault.load(1);
        Collateral.Data storage collateral = vault.collateral;
        collateral.asset = address(wBtc);

        // Set the market ID and WETH address
        marketMakingEngine.workaround_setMarketId(1, 1);
        marketMakingEngine.workaround_setWethAddress(address(wEth));

        // set contract with initial wBtc fees
        deal(address(wBtc), address(perpsEngine), 20e18);
        IERC20(address(wBtc)).approve(thisContractAddr, 10e18);
        marketMakingEngine.receiveOrderFee(1, address(wBtc), 10e18);

        // Set percentage ratio for market and fee recipients
        marketMakingEngine.setPercentageRatio(1, 3500, 6500);

        // set contract with initial wEth fees
        deal(address(wEth), address(perpsEngine), 10e18);
        IERC20(address(wEth)).approve(thisContractAddr, 10e18);
        marketMakingEngine.receiveOrderFee(1, address(wEth), 10e18);

        // set contract with initial usdz fees
        deal(address(usdz), address(perpsEngine), 10e18);
        IERC20(address(usdz)).approve(thisContractAddr, 10e18);
        marketMakingEngine.receiveOrderFee(1, address(usdz), 10e18);
    }

    function test_RevertGiven_TheCallerIsNotPerpsEngine() external {
        changePrank({ msgSender: users.naruto.account });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.Unauthorized.selector, users.naruto.account) });
        marketMakingEngine.convertAccumulatedFeesToWeth(1, address(wBtc));
    }

    modifier givenTheCallerIsPerpEngine() {
        _;
    }

    function test_RevertWhen_MarketDoesNotExist() external givenTheCallerIsPerpEngine {
        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.UnrecognisedMarket.selector) });
        marketMakingEngine.convertAccumulatedFeesToWeth(0, address(wBtc));
    }

    modifier whenMarketExist() {
        _;
    }

    function test_RevertGiven_TheAmountIsZero() external givenTheCallerIsPerpEngine whenMarketExist {
        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.InvalidAsset.selector) });
        marketMakingEngine.convertAccumulatedFeesToWeth(1, address(usdc));
    }

    modifier givenTheAmountIsNotZero() {
        _;
    }

    function test_GivenTheAssetIsWeth()
        external
        givenTheCallerIsPerpEngine
        whenMarketExist
        givenTheAmountIsNotZero
    {
        // it should emit event { OrderFeeReceived }
        vm.expectEmit();
        emit FeeDistributionBranch.FeesConvertedToWETH(
            address(wEth), 10e18, 10e18
        );

        marketMakingEngine.convertAccumulatedFeesToWeth(1, address(wEth));

        uint256 marketFees = marketMakingEngine.workaround_getMarketFees(1);
        uint256 feeRecipientsFees = marketMakingEngine.workaround_getFeeRecipientsFees(1);

        // it should divide amount between market and fee recipients
        assertEq(marketFees, 65e17);
        assertEq(feeRecipientsFees, 35e17);
    }

    modifier givenTheAssetIsNotWeth() {
        _;
    }

    function test_RevertWhen_PriceAdapterAddressIsNotSet()
        external
        givenTheCallerIsPerpEngine
        whenMarketExist
        givenTheAmountIsNotZero
        givenTheAssetIsNotWeth
    {
        // Deploy MockUniswapRouter to simulate the swap
        ISwapRouter swapRouter = ISwapRouter(address(new MockUniswapRouter()));

        // Mock the Uniswap router
        marketMakingEngine.exposed_setUniswapRouterAddress(address(swapRouter)); 

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.PriceAdapterUndefined.selector) });
        marketMakingEngine.convertAccumulatedFeesToWeth(1, address(wBtc));
    }

    modifier whenPriceAdapterAddressIsSet() {
        _;
    }

    function test_RevertGiven_TheUniswapAddressIsNotSet()
        external
        givenTheCallerIsPerpEngine
        whenMarketExist
        givenTheAmountIsNotZero
        givenTheAssetIsNotWeth
        whenPriceAdapterAddressIsSet
    { 
        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.SwapRouterAddressUndefined.selector) });
        marketMakingEngine.convertAccumulatedFeesToWeth(1, address(wBtc));
    }

    function test_GivenTheUniswapAddressIsSetAndDecimalsAreLessThan18()
        external
        givenTheCallerIsPerpEngine
        whenMarketExist
        givenTheAmountIsNotZero
        givenTheAssetIsNotWeth
        whenPriceAdapterAddressIsSet
    {   
        // Deploy MockUniswapRouter to simulate the swap
        ISwapRouter swapRouter = ISwapRouter(address(new MockUniswapRouter()));

        // Mock the Uniswap router
        marketMakingEngine.exposed_setUniswapRouterAddress(address(swapRouter)); 

        // Deploy MockPriceAdapter with an initial price
        MockPriceFeed wbtcMockPriceFeed = new MockPriceFeed(8, 1e18);
        MockPriceFeed wethMockPriceFeed = new MockPriceFeed(18, 2e18);

        // Set collateral types params
        marketMakingEngine.workaround_Collateral_setParams(address(wBtc), 1.5e18, 120, true, 8, address(wbtcMockPriceFeed));
        marketMakingEngine.workaround_Collateral_setParams(address(wEth), 2e18, 120, true, 18, address(wethMockPriceFeed));

        // Expect event emitted for fee conversion 
        vm.expectEmit();
        emit FeeDistributionBranch.FeesConvertedToWETH(address(wBtc), 10e18, 20e18);  // Mock returns 2x the input amount

        // Call the function to convert accumulated fees to WETH from wBtc (token with less than 18 decimalsa)
        marketMakingEngine.convertAccumulatedFeesToWeth(1, address(wBtc));

        // Check the resulting split of fees between market and fee recipients  
        uint256 marketFees = marketMakingEngine.workaround_getMarketFees(1);
        uint256 feeRecipientsFees = marketMakingEngine.workaround_getFeeRecipientsFees(1);

        // it should divide amount between market and fee recipients
        assertEq(marketFees, (20e18 * 6500) / 10000);
        assertEq(feeRecipientsFees, (20e18 * 3500) / 10000);  
    }

    function test_GivenTheUniswapAddressAndDecimalsAre18()
        external
        givenTheCallerIsPerpEngine
        whenMarketExist
        givenTheAmountIsNotZero
        givenTheAssetIsNotWeth
        whenPriceAdapterAddressIsSet
    {   
        // Deploy MockUniswapRouter to simulate the swap
        ISwapRouter swapRouter = ISwapRouter(address(new MockUniswapRouter()));

        // Mock the Uniswap router
        marketMakingEngine.exposed_setUniswapRouterAddress(address(swapRouter)); 

        // Deploy MockPriceAdapter with an initial price
        MockPriceFeed wethMockPriceFeed = new MockPriceFeed(18, 2e18);
        MockPriceFeed usdzMockPriceFeed = new MockPriceFeed(18, 1e18);

        // Set collateral types params
        marketMakingEngine.workaround_Collateral_setParams(address(wEth), 2e18, 120, true, 18, address(wethMockPriceFeed));
        marketMakingEngine.workaround_Collateral_setParams(address(usdz), 2e18, 120, true, 18, address(usdzMockPriceFeed));

        // Expect event emitted for fee conversion 
        vm.expectEmit();
        emit FeeDistributionBranch.FeesConvertedToWETH(address(usdz), 10e18, 20e18);  // Mock returns 2x the input amount

        // Call the function to convert accumulated fees to WETH from usdz (token with 18 decimalsa)
        marketMakingEngine.convertAccumulatedFeesToWeth(1, address(usdz));

        // Check the resulting split of fees between market and fee recipients  
        uint256 marketFees = marketMakingEngine.workaround_getMarketFees(1);
        uint256 feeRecipientsFees = marketMakingEngine.workaround_getFeeRecipientsFees(1);

        // it should divide amount between market and fee recipients
        assertEq(marketFees, (20e18 * 6500) / 10000);
        assertEq(feeRecipientsFees, (20e18 * 3500) / 10000);  
    }
}
