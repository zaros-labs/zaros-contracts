// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { IFeeManager, FeeAsset } from "./interfaces/IFeeManager.sol";
import { BasicReport, PremiumReport } from "./interfaces/IStreamsLookupCompatible.sol";
import { IVerifierProxy } from "./interfaces/IVerifierProxy.sol";
import { Constants } from "@zaros/utils/Constants.sol";

// Open Zeppelin dependencies
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

library ChainlinkUtil {
    using SafeCast for int256;

    /// @notice Decodes the signedReport object and returns the report data only.
    function getReportData(bytes memory signedReport) internal pure returns (bytes memory reportData) {
        (, reportData) = abi.decode(signedReport, (bytes32[3], bytes));
    }

    /// @notice Converts the provided report price to UD60x18.
    /// @dev Reports' prices at the current Data Streams version have 8 decimals.
    /// @param reportData The raw report data byte array.
    /// @param decimals The report price's decimals.
    /// @param isPremium Whether the report is premium or not.
    /// @return reportPrice The converted price to UD60x18.
    function getReportPriceUd60x18(
        bytes memory reportData,
        uint8 decimals,
        bool isPremium
    )
        internal
        view
        returns (UD60x18 reportPrice)
    {
        if (isPremium) {
            PremiumReport memory report = abi.decode(reportData, (PremiumReport));
            reportPrice = ChainlinkUtil.convertReportPriceToUd60x18(report.price, decimals);
        } else {
            BasicReport memory report = abi.decode(reportData, (BasicReport));
            reportPrice = ChainlinkUtil.convertReportPriceToUd60x18(report.price, decimals);
        }
    }

    /// @notice Converts the provided report price to UD60x18.
    /// @dev Reports' prices at the current Data Streams version have 8 decimals.
    /// @param price The price to convert.
    /// @param decimals The report price's decimals.
    /// @return priceUd60x18 The converted price to UD60x18.
    function convertReportPriceToUd60x18(int192 price, uint8 decimals) internal view returns (UD60x18) {
        if (Constants.SYSTEM_DECIMALS == decimals) {
            return ud60x18(reportPriceToUint256(price));
        }
        return ud60x18(reportPriceToUint256(price) * 10 ** (Constants.SYSTEM_DECIMALS - decimals));
    }

    /// @notice Convert the provided int192 report price to uint256.
    /// @param price The price to convert.
    function reportPriceToUint256(int192 price) internal view returns (uint256) {
        return int256(price).toUint256();
    }

    function getEthVericationFee(
        IVerifierProxy chainlinkVerifier,
        bytes memory reportData
    )
        internal
        returns (FeeAsset memory)
    {
        IFeeManager chainlinkFeeManager = chainlinkVerifier.s_feeManager();
        // TODO: Store preferred fee token instead of querying i_nativeAddress?
        address feeTokenAddress = chainlinkFeeManager.i_nativeAddress();
        (FeeAsset memory fee,,) = chainlinkFeeManager.getFeeAndReward(address(this), reportData, feeTokenAddress);
    }

    function verifyReport(
        IVerifierProxy chainlinkVerifier,
        FeeAsset memory fee,
        bytes memory signedReport
    )
        internal
        returns (bytes memory verifiedReportData)
    {
        verifiedReportData = chainlinkVerifier.verify{ value: fee.amount }(signedReport, abi.encode(fee.assetAddress));
    }
}
