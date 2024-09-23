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
import { SwapStrategy } from "@zaros/market-making/leaves/SwapStrategy.sol";

// Openzeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/extensions/ERC4626.sol";
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";

// UniSwap dependencies
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

contract ConvertAccumulatedFeesToWeth_Integration_Test is Base_Test {
    using EnumerableSet for EnumerableSet.UintSet;

    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID);
        changePrank({ msgSender: address(perpsEngine) });

        marketMakingEngine.workaround_setPerpsEngineAddress(address(perpsEngine));

        // Deploy MockPriceAdapter with an initial price
        MockPriceFeed wbtcMockPriceFeed = new MockPriceFeed(8, 1e18);
        MockPriceFeed wethMockPriceFeed = new MockPriceFeed(8, 2e18);
        MockPriceFeed usdzMockPriceFeed = new MockPriceFeed(8, 1e18);

        // Set collateral types params
        marketMakingEngine.workaround_Collateral_setParams(
            address(wBtc), 
            2e18, 
            120, 
            true, 
            8, 
            address(wbtcMockPriceFeed)
        );
        marketMakingEngine.workaround_Collateral_setParams(
            address(wEth), 
            2e18, 
            120, 
            true, 
            18, 
            address(wethMockPriceFeed)
        );
        marketMakingEngine.workaround_Collateral_setParams(
            address(usdz), 
            2e18, 
            120, 
            true, 
            18, 
            address(usdzMockPriceFeed)
        );

        // set vault collateral types
        Vault.Data storage vault = Vault.load(1);
        vault.collateral.isEnabled = true;
        vault.collateral.asset = address(wBtc);
        
        // Set the market ID and WETH address
        marketMakingEngine.workaround_setMarketId(1, 1);
        marketMakingEngine.workaround_setWethAddress(address(wEth));

        // set contract with initial wBtc fees
        deal(address(wBtc), address(perpsEngine), 20e18);
        IERC20(address(wBtc)).approve(address(marketMakingEngine), 10e18);
        marketMakingEngine.receiveOrderFee(1, address(wBtc), 10e18);

        changePrank({ msgSender: users.owner.account });
        // Set percentage ratio for market and fee recipients
        marketMakingEngine.setPercentageRatio(1, 6500, 3500);

        changePrank({ msgSender: address(perpsEngine) });
        // set contract with initial wEth fees
        deal(address(wEth), address(perpsEngine), 10e18);
        IERC20(address(wEth)).approve(address(marketMakingEngine), 10e18);
        marketMakingEngine.receiveOrderFee(1, address(wEth), 10e18);

        // set contract with initial usdz fees
        deal(address(usdz), address(perpsEngine), 10e18);
        IERC20(address(usdz)).approve(address(marketMakingEngine), 10e18);
        marketMakingEngine.receiveOrderFee(1, address(usdz), 10e18);
    }

    function test_RevertGiven_TheCallerIsNotMarketMakingEngine() external {
        changePrank({ msgSender: users.naruto.account });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.Unauthorized.selector, users.naruto.account) });
        marketMakingEngine.convertAccumulatedFeesToWeth(1, address(wBtc));
    }

    modifier givenTheCallerIsMarketMakingEngine() {
        _;
    }

    function test_RevertWhen_MarketDoesNotExist() external givenTheCallerIsMarketMakingEngine {
        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.UnrecognisedMarket.selector) });
        marketMakingEngine.convertAccumulatedFeesToWeth(0, address(wBtc));
    }

    modifier whenMarketExist() {
        _;
    }

    function test_RevertWhen_TheAmountIsZero() external givenTheCallerIsMarketMakingEngine whenMarketExist {
        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.InvalidAsset.selector) });
        marketMakingEngine.convertAccumulatedFeesToWeth(1, address(usdc));
    }

    modifier whenTheAmountIsNotZero() {
        _;
    }

    modifier whenTheAssetExists() {
        _;
    }

    function test_WhenTheAssetIsWeth()
        external
        givenTheCallerIsMarketMakingEngine
        whenMarketExist
        whenTheAmountIsNotZero
        whenTheAssetExists
    {
        // it should emit event { LogConvertAccumulatedFeesToWeth }
        vm.expectEmit();
        emit FeeDistributionBranch.LogConvertAccumulatedFeesToWeth(
            address(wEth), 10e18, 10e18
        );

        marketMakingEngine.convertAccumulatedFeesToWeth(1, address(wEth));

        uint256 marketFees = marketMakingEngine.workaround_getMarketFees(1);
        uint256 feeRecipientsFees = marketMakingEngine.workaround_getFeeRecipientsFees(1);

        // it should divide amount between market and fee recipients
        assertEq(marketFees, 65e17);
        assertEq(feeRecipientsFees, 35e17);
    }

    modifier whenTheAssetIsNotWeth() {
        _;
    }

    function test_RevertGiven_PriceAdapterAddressIsNotSet()
        external
        givenTheCallerIsMarketMakingEngine
        whenMarketExist
        whenTheAmountIsNotZero
        whenTheAssetExists
        whenTheAssetIsNotWeth
    {
        // Deploy MockUniswapRouter to simulate the swap
        ISwapRouter swapRouter = ISwapRouter(address(new MockUniswapRouter()));

        // Mock the Uniswap router
        marketMakingEngine.exposed_setUniswapRouterAddress(address(swapRouter)); 

        // Set Price Adapter address to zero
        marketMakingEngine.workaround_Collateral_setParams(address(wBtc), 2e18, 120, true, 8, address(0));

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.PriceAdapterUndefined.selector) });
        marketMakingEngine.convertAccumulatedFeesToWeth(1, address(wBtc));
    }

    modifier givenPriceAdapterAddressIsSet() {
        _;
    }

    function test_RevertGiven_TheUniswapAddressIsNotSet()
        external
        givenTheCallerIsMarketMakingEngine
        whenMarketExist
        whenTheAmountIsNotZero
        whenTheAssetExists
        whenTheAssetIsNotWeth
        givenPriceAdapterAddressIsSet
    {
        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "uniswap router address") });
        marketMakingEngine.convertAccumulatedFeesToWeth(1, address(wBtc));
    }

    modifier givenTheUniswapAddressIsSet() {
        _;
    }

    function test_GivenTokenInDecimalsAreLessThan18()
        external
        givenTheCallerIsMarketMakingEngine
        whenMarketExist
        whenTheAmountIsNotZero
        whenTheAssetExists
        whenTheAssetIsNotWeth
        givenPriceAdapterAddressIsSet
        givenTheUniswapAddressIsSet
    {
        // Deploy MockUniswapRouter to simulate the swap
        ISwapRouter swapRouter = ISwapRouter(address(new MockUniswapRouter()));

        // Mock the Uniswap router
        marketMakingEngine.exposed_setUniswapRouterAddress(address(swapRouter)); 

        // Expect event emitted for fee conversion 
        vm.expectEmit();
        emit FeeDistributionBranch.LogConvertAccumulatedFeesToWeth(address(wBtc), 10e18, 10e18);  

        // Call the function to convert accumulated fees to WETH from wBtc (token with less than 18 decimals)
        marketMakingEngine.convertAccumulatedFeesToWeth(1, address(wBtc));

        // Check the resulting split of fees between market and fee recipients  
        uint256 marketFees = marketMakingEngine.workaround_getMarketFees(1);
        uint256 feeRecipientsFees = marketMakingEngine.workaround_getFeeRecipientsFees(1);

        (uint128 marketPercentage, uint128 feeRecipientsPercentage) = marketMakingEngine.getPercentageRatio(1);

        // it should divide amount between market and fee recipients
        assertEq(marketFees, (10e18 * marketPercentage) / SwapStrategy.BPS_DENOMINATOR);
        assertEq(feeRecipientsFees, (10e18 * feeRecipientsPercentage) / SwapStrategy.BPS_DENOMINATOR);  
    }

    function test_GivenTokenInDecimalsAre18()
        external
        givenTheCallerIsMarketMakingEngine
        whenMarketExist
        whenTheAmountIsNotZero
        whenTheAssetExists
        whenTheAssetIsNotWeth
        givenPriceAdapterAddressIsSet
        givenTheUniswapAddressIsSet
    {
        // Deploy MockUniswapRouter to simulate the swap
        ISwapRouter swapRouter = ISwapRouter(address(new MockUniswapRouter()));

        // Mock the Uniswap router
        marketMakingEngine.exposed_setUniswapRouterAddress(address(swapRouter)); 

        // Expect event emitted for fee conversion 
        vm.expectEmit();
        emit FeeDistributionBranch.LogConvertAccumulatedFeesToWeth(address(usdz), 10e18, 10e18); 

        // Call the function to convert accumulated fees to WETH from usdz (token with 18 decimalsa)
        marketMakingEngine.convertAccumulatedFeesToWeth(1, address(usdz));

        // Check the resulting split of fees between market and fee recipients  
        uint256 marketFees = marketMakingEngine.workaround_getMarketFees(1);
        uint256 feeRecipientsFees = marketMakingEngine.workaround_getFeeRecipientsFees(1);

        // it should divide amount between market and fee recipients
        assertEq(marketFees, (10e18 * 6500) / 10000);
        assertEq(feeRecipientsFees, (10e18 * 3500) / 10000);  
    }

    function test_GivenTokenInDecimalsAreMoreThan18()
        external
        givenTheCallerIsMarketMakingEngine
        whenMarketExist
        whenTheAmountIsNotZero
        whenTheAssetExists
        whenTheAssetIsNotWeth
        givenPriceAdapterAddressIsSet
        givenTheUniswapAddressIsSet
    {
        // Deploy MockUniswapRouter to simulate the swap
        ISwapRouter swapRouter = ISwapRouter(address(new MockUniswapRouter()));

        // Mock the Uniswap router
        marketMakingEngine.exposed_setUniswapRouterAddress(address(swapRouter)); 
        
        // Set tokenIn decimals > 18
        MockPriceFeed usdzMockPriceFeed = new MockPriceFeed(8, 1e18);
        marketMakingEngine.workaround_Collateral_setParams(
            address(usdz), 
            2e18, 
            120, 
            true, 
            20, 
            address(usdzMockPriceFeed)
        );

        // Expect event emitted for fee conversion 
        vm.expectEmit();
        emit FeeDistributionBranch.LogConvertAccumulatedFeesToWeth(address(usdz), 10e18, 10e18); 

        // Call the function to convert accumulated fees to WETH from usdz (token with 18 decimalsa)
        marketMakingEngine.convertAccumulatedFeesToWeth(1, address(usdz));

        // Check the resulting split of fees between market and fee recipients  
        uint256 marketFees = marketMakingEngine.workaround_getMarketFees(1);
        uint256 feeRecipientsFees = marketMakingEngine.workaround_getFeeRecipientsFees(1);

        // it should divide amount between market and fee recipients
        assertEq(marketFees, (10e18 * 6500) / 10000);
        assertEq(feeRecipientsFees, (10e18 * 3500) / 10000);  
    }
}
