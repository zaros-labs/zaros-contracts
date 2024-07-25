// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test, IPerpsEngine } from "test/Base.t.sol";
import { getBranchesSelectors } from "script/utils/TreeProxyUtils.sol";

// Forge dependencies
import { StdInvariant } from "forge-std/StdInvariant.sol";

//
// Foundry Fuzzer Info:
//
// run from base project directory with:
// forge test --match-contract TestInvariantFoundry
//

/// @title TestInvariantFoundry
/// @notice This contract is used to test the invariants scenarios
contract TestInvariantFoundry is Base_Test, StdInvariant {
    function setUp() public override {
        // Setup the system
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        configureSystemParameters();
        createPerpMarkets();

        // Mint tokens for the users
        mintTokens();

        // Create trading accounts for some users
        changePrank({ msgSender: users.naruto.account });
        perpsEngine.createTradingAccount(bytes(""), false);

        changePrank({ msgSender: users.sasuke.account });
        perpsEngine.createTradingAccount(bytes(""), false);

        // Config targetSender users
        targetSender(users.owner.account);
        targetSender(users.naruto.account);
        targetSender(users.sasuke.account);
        targetSender(users.sakura.account);
        targetSender(users.madara.account);

        // Config targetContract
        targetContract(address(perpsEngine));

        // Config targetSelector
        bytes4[][] memory branchesSelectors = getBranchesSelectors(false);

        bytes4[] memory selectors = new bytes4[](58);

        uint256 selectorsIndex = 0;
        for(uint i; i < branchesSelectors.length; i++) {
            for(uint j; j < branchesSelectors[i].length; j++) {
                selectors[selectorsIndex] = (branchesSelectors[i][j]);
                selectorsIndex++;
            }
        }

        targetSelector(FuzzSelector({
            addr: address(IPerpsEngine(perpsEngine)),
            selectors: selectors
        }));
    }

    /* DEFINE INVARIANTS HERE */
    //
    // changed invariants to use assertions for Foundry

    // INVARIANT 1) The total deposited of each collateral should be less than or equal of the each deposit cap
    function _getTheTotalDepositedOfEachCollateralShouldBeLessThanOrEqualOfTheEachDepositCap() private view returns (bool) {
        for (uint256 i = INITIAL_MARGIN_COLLATERAL_ID; i <= FINAL_MARGIN_COLLATERAL_ID; i++) {
            uint256 totalDeposited = perpsEngine.workaround_getTotalDeposited(marginCollaterals[i].marginCollateralAddress);

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
