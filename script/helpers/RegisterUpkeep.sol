// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Open zeppelin upgradeable dependencies
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";

interface LinkTokenInterface {
    function allowance(address owner, address spender) external view returns (uint256 remaining);

    function approve(address spender, uint256 value) external returns (bool success);

    function balanceOf(address owner) external view returns (uint256 balance);

    function decimals() external view returns (uint8 decimalPlaces);

    function decreaseApproval(address spender, uint256 addedValue) external returns (bool success);

    function increaseApproval(address spender, uint256 subtractedValue) external;

    function name() external view returns (string memory tokenName);

    function symbol() external view returns (string memory tokenSymbol);

    function totalSupply() external view returns (uint256 totalTokensIssued);

    function transfer(address to, uint256 value) external returns (bool success);

    function transferAndCall(address to, uint256 value, bytes calldata data) external returns (bool success);

    function transferFrom(address from, address to, uint256 value) external returns (bool success);
}

struct RegistrationParams {
    string name;
    bytes encryptedEmail;
    address upkeepContract;
    uint32 gasLimit;
    address adminAddress;
    uint8 triggerType;
    bytes checkData;
    bytes triggerConfig;
    bytes offchainConfig;
    uint96 amount;
}

interface AutomationRegistrarInterface {
    function registerUpkeep(RegistrationParams calldata requestParams) external returns (uint256);
}

contract RegisterUpkeep is UUPSUpgradeable, OwnableUpgradeable {
    LinkTokenInterface public i_link;
    AutomationRegistrarInterface public i_registrar;

    error AutoApproveDisabled();

    function initialize(
        address owner,
        LinkTokenInterface link,
        AutomationRegistrarInterface registrar
    )
        external
        initializer
    {
        i_link = link;
        i_registrar = registrar;

        __Ownable_init(owner);
    }

    function registerAndPredictID(RegistrationParams memory params) public returns (uint256 upkeepId) {
        // LINK must be approved for transfer - this can be done every time or once
        // with an infinite approval
        i_link.approve(address(i_registrar), params.amount);
        upkeepId = i_registrar.registerUpkeep(params);
        if (upkeepId == 0) {
            revert AutoApproveDisabled();
        }
    }

    function _authorizeUpgrade(address newImplementation) internal virtual override { }
}
