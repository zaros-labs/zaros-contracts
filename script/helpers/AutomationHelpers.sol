// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";

import "forge-std/console.sol";

struct RegistrationParams {
    string name;
    bytes encryptedEmail;
    address keeperContract;
    uint32 gasLimit;
    address adminAddress;
    uint8 triggerType;
    bytes checkData;
    bytes triggerConfig;
    bytes offchainConfig;
    uint96 amount;
}

interface AutomationRegistrarInterface {
    function registerKeeper(RegistrationParams calldata requestParams) external returns (uint256);
}

library AutomationHelpers {
    uint32 internal constant GAS_LIMIT = 5_000_000;
    uint8 internal constant CONDITIONAL_TRIGGER_TYPE = 0;
    uint8 internal constant LOG_TRIGGER_TYPE = 1;

    function getLiquidationKeeperConfig()
        internal
        pure
        returns (bytes memory checkData, bytes memory triggerConfig)
    {
        uint256 checkLowerBound = 0;
        uint256 checkUpperBound = 500;

        uint256 performLowerBound = 0;
        uint256 performUpperBound = 20;

        checkData = abi.encode(checkLowerBound, checkUpperBound, performLowerBound, performUpperBound);
        triggerConfig = bytes("");
    }

    function registerLiquidationKeeper(
        string memory name,
        address liquidationKeeper,
        address link,
        address registrar,
        address adminAddress,
        uint256 linkAmount
    )
        internal
    {
        (bytes memory checkData, bytes memory triggerConfig) = getLiquidationKeeperConfig();
        console.log(IERC20(link).balanceOf(adminAddress));
        IERC20(link).approve(registrar, linkAmount);

        RegistrationParams memory params = RegistrationParams({
            name: name,
            encryptedEmail: bytes(""),
            keeperContract: liquidationKeeper,
            gasLimit: GAS_LIMIT,
            adminAddress: adminAddress,
            triggerType: CONDITIONAL_TRIGGER_TYPE,
            checkData: checkData,
            triggerConfig: triggerConfig,
            offchainConfig: bytes(""),
            amount: uint96(linkAmount)
        });
        AutomationRegistrarInterface(registrar).registerKeeper(params);
    }
}
