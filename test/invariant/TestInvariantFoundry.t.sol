// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test, IPerpsEngine } from "test/Base.t.sol";
import { getBranchesSelectors } from "script/utils/TreeProxyUtils.sol";

// Forge dependencies
import { StdInvariant } from "forge-std/StdInvariant.sol";

// PRB Math dependencies
import { ud60x18 } from "@prb-math/UD60x18.sol";

//
// Foundry Fuzzer Info:
//
// run from base project directory with:
// forge test --match-contract TestInvariantFoundry
// forge coverage --match-contract TestInvariantFoundry
//

/// @title TestInvariantFoundry
/// @notice This contract is used to test the invariants scenarios
contract TestInvariantFoundry is Base_Test, StdInvariant {
    function setUp() public override {
        // Setup the system
        usePerpsEngineInvariantTest = true;
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        configureSystemParameters();
        createPerpMarkets();

        // Mint tokens for the users
        mintTokens();

        // Create custom referrals
        changePrank({ msgSender: users.owner.account });
        perpsEngine.createCustomReferralCode(users.naruto.account, "NARUTO");

        // Create trading accounts for some users but not for all
        changePrank({ msgSender: users.naruto.account });
        uint128 narutoTradingAccountId = perpsEngine.createTradingAccount(bytes(""), false);

        changePrank({ msgSender: users.sasuke.account });
        uint128 sasukeTradingAccountId = perpsEngine.createTradingAccount(bytes("NARUTO"), true);

        changePrank({ msgSender: users.sakura.account });
        uint128 sakuraTraindgAccountId = perpsEngine.createTradingAccount(abi.encode(users.sasuke.account), false);

        changePrank({ msgSender: users.madara.account });
        perpsEngine.createTradingAccount(bytes(""), false);

        // Deposit for some users but not for all
        changePrank({ msgSender: users.naruto.account });
        uint256 amountToDepositMarginUsdc = convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18);
        perpsEngine.depositMargin(narutoTradingAccountId, address(usdc), amountToDepositMarginUsdc);

        changePrank({ msgSender: users.sasuke.account });
        uint256 amountToDepositMarginWstEth = convertUd60x18ToTokenAmount(address(wstEth), WSTETH_DEPOSIT_CAP_X18);
        perpsEngine.depositMargin(sasukeTradingAccountId, address(wstEth), amountToDepositMarginWstEth);

        changePrank({ msgSender: users.sakura.account });
        uint256 amountToDepositMarginWbtc = convertUd60x18ToTokenAmount(address(wBtc), WBTC_DEPOSIT_CAP_X18);
        perpsEngine.depositMargin(sakuraTraindgAccountId, address(wBtc), amountToDepositMarginWbtc);

        // Open position for some users but not for all
        changePrank({ msgSender: users.naruto.account });
        uint256 firstMarketId;
        firstMarketId = bound({ x: firstMarketId, min: 0, max: type(uint256).max });
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(firstMarketId);
        openPosition(
            fuzzMarketConfig,
            narutoTradingAccountId,
            ud60x18(fuzzMarketConfig.imr).mul(ud60x18(1.001e18)).intoUint256(),
            amountToDepositMarginUsdc,
            true
        );

        changePrank({ msgSender: users.sasuke.account });
        uint256 secondMarketId = firstMarketId++;
        secondMarketId = bound({ x: secondMarketId, min: 0, max: type(uint256).max });
        MarketConfig memory secondFuzzMarketConfig = getFuzzMarketConfig(secondMarketId);
        openPosition(
            secondFuzzMarketConfig,
            sasukeTradingAccountId,
            ud60x18(secondFuzzMarketConfig.imr).mul(ud60x18(1.001e18)).intoUint256(),
            amountToDepositMarginWstEth,
            false
        );

        // Set some accounts as liquidatable but not all
        setAccountsAsLiquidatable(secondFuzzMarketConfig, false);

        // Config targetSender users
        targetSender(users.owner.account);
        targetSender(users.naruto.account);
        targetSender(users.sasuke.account);
        targetSender(users.sakura.account);
        targetSender(users.madara.account);
        targetSender(users.minato.account);
        targetSender(address(perpsEngine));

        // Config targetContract
        targetContract(address(perpsEngine));

        // Config targetSelector
        bytes4[][] memory branchesSelectors = getBranchesSelectors(false);

        bytes4[] memory selectors = new bytes4[](58);

        uint256 selectorsIndex = 0;
        for (uint256 i; i < branchesSelectors.length; i++) {
            for (uint256 j; j < branchesSelectors[i].length; j++) {
                selectors[selectorsIndex] = (branchesSelectors[i][j]);
                selectorsIndex++;
            }
        }

        targetSelector(FuzzSelector({ addr: address(IPerpsEngine(perpsEngine)), selectors: selectors }));
    }

    /* DEFINE INVARIANTS HERE */
    //
    // changed invariants to use assertions for Foundry

    // INVARIANT 1) The total deposited of each collateral should be less than or equal of the each deposit cap
    function _getTheTotalDepositedOfEachCollateralShouldBeLessThanOrEqualOfTheEachDepositCap()
        private
        view
        returns (bool)
    {
        for (uint256 i = INITIAL_MARGIN_COLLATERAL_ID; i <= FINAL_MARGIN_COLLATERAL_ID; i++) {
            uint256 totalDeposited =
                perpsEngine.workaround_getTotalDeposited(marginCollaterals[i].marginCollateralAddress);

            if (totalDeposited > uint256(marginCollaterals[i].depositCap)) {
                return false;
            }
        }
        return true;
    }

    function invariant_TheTotalDepositedOfEachCollateralShouldBeLessThanOrEqualOfTheEachDepositCap() public {
        assertEq(_getTheTotalDepositedOfEachCollateralShouldBeLessThanOrEqualOfTheEachDepositCap(), true);
    }
}
