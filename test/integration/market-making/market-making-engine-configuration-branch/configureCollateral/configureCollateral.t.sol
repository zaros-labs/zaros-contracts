// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies test
import { Base_Test } from "test/Base.t.sol";

contract MarketMakingEngine_ConfigureCollateral_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
    }

    function test_RevertGiven_TheSenderIsNotTheOwner() external {
        // it should revert
    }

    modifier givenTheSenderIsTheOwner() {
        _;
    }

    function test_RevertWhen_CollateralIsZero() external givenTheSenderIsTheOwner {
        // it should revert
    }

    modifier whenCollateralIsNotZero() {
        _;
    }

    function test_RevertWhen_PriceAdapterIsZero() external givenTheSenderIsTheOwner whenCollateralIsNotZero {
        // it should revert
    }

    modifier whenPriceAdapterIsNotZero() {
        _;
    }

    function test_RevertWhen_CreditRatioIsZero()
        external
        givenTheSenderIsTheOwner
        whenCollateralIsNotZero
        whenPriceAdapterIsNotZero
    {
        // it should revert
    }

    modifier whenCreditRatioIsNotZero() {
        _;
    }

    function test_RevertWhen_DecimalsIsZero()
        external
        givenTheSenderIsTheOwner
        whenCollateralIsNotZero
        whenPriceAdapterIsNotZero
        whenCreditRatioIsNotZero
    {
        // it should revert
    }

    function test_WhenDecimalsIsNotZero()
        external
        givenTheSenderIsTheOwner
        whenCollateralIsNotZero
        whenPriceAdapterIsNotZero
        whenCreditRatioIsNotZero
    {
        // it should update collateral storage
        // it should emit {LogConfigureCollateral} event
    }
}
