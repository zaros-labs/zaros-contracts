// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

library AddressError {
    error Zaros_ZeroAddress();
    error Zaros_Unauthorized(address sender);
}

/**
 * @title Library for errors related with expected function parameters.
 */
library ParameterError {
    /**
     * @dev Thrown when an invalid parameter is used in a function.
     * @param parameter The name of the parameter.
     * @param reason The reason why the received parameter is invalid.
     */
    error Zaros_InvalidParameter(string parameter, string reason);
}
