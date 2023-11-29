// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

library ChainlinkUtil {
    /// @notice Decodes the signedReport object and returns the report data only.
    function getReportData(bytes memory signedReport) internal pure returns (bytes memory reportData) {
        (, reportData) = abi.decode(signedReport, (bytes32[3], bytes));
    }
}
