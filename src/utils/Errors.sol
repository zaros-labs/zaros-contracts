// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

library AddressError {
    error Zaros_ZeroAddress();
    error Zaros_Unauthorized(address sender);
}

library ParameterError {
    error Zaros_InvalidParameter(string parameter, string reason);
}
