// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Open Zeppelin dependencies
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";

/// @notice Whitelist is the contract to control the access of the user in the perps engine and market making engine
contract Whitelist is OwnableUpgradeable, UUPSUpgradeable {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice The whitelist.
    mapping(address user => bool isAllowed) whitelist;

    /*//////////////////////////////////////////////////////////////////////////
                                     EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Event emitted when whitelist is updated.
    /// @param user The user address.
    /// @param isAllowed True if the user is allowed or false otherwise.
    event LogUpdateWhitelist(address indexed user, bool isAllowed);

    /*//////////////////////////////////////////////////////////////////////////
                                     EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    error OwnerCantBeUpdatedInTheWhitelist();

    /*//////////////////////////////////////////////////////////////////////////
                                     INITIALIZE
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Called when initialize the contract
    /// @param owner The owner of the contract
    function initialize(address owner) external initializer {
        __Ownable_init(owner);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Function to control the updates in the whitelist
    /// @param userList The array of user addresses
    /// @param isAllowedList The array of booleans that indicates if user is allowed
    function updateWhitelist(address[] memory userList, bool[] memory isAllowedList) public onlyOwner {
        // verify array mismatch
        if (userList.length != isAllowedList.length) {
            revert Errors.ArrayLengthMismatch(userList.length, isAllowedList.length);
        }

        // cache the user list length
        uint256 userListLengthCache = userList.length;

        for (uint256 i; i < userListLengthCache; i++) {
            // the owner always is allowed
            if (userList[i] == owner()) {
                revert OwnerCantBeUpdatedInTheWhitelist();
            }

            // update the whitelist
            whitelist[userList[i]] = isAllowedList[i];

            // emit the update whitelist event
            emit LogUpdateWhitelist(userList[i], isAllowedList[i]);
        }
    }

    /// @notice Verify if user is allowed
    /// @param user The user address
    function verifyIfUserIsAllowed(address user) public view returns (bool) {
        return whitelist[user];
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    UPGRADEABLE FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Upgrades the contract
    /// @dev This function is called by the proxy when the contract is upgraded
    /// @dev Only the owner can upgrade the contract
    function _authorizeUpgrade(address) internal override onlyOwner { }
}
