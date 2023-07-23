// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { Constants } from "@zaros/utils/Constants.sol";
import { IAggregatorV3 } from "@zaros/external/interfaces/chainlink/IAggregatorV3.sol";
import { OrderFees } from "../storage/OrderFees.sol";

// Open Zeppelin dependencies
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

library PerpsMarketConfig {
    using SafeCast for int256;

    bytes32 internal constant PERPS_MARKET_CONFIG_SLOT = keccak256(abi.encode("fi.zaros.markets.PerpsMarketConfig"));

    struct Data {
        string name;
        string symbol;
        int256 skew;
        uint256 size;
        address oracle;
        address perpsVault;
        OrderFees.Data orderFees;
    }

    function load() internal pure returns (Data storage perpsMarketConfig) {
        bytes32 slot = PERPS_MARKET_CONFIG_SLOT;
        assembly {
            perpsMarketConfig.slot := slot
        }
    }

    /// @dev TODO: improve this
    function getIndexPrice(Data storage self) internal view returns (UD60x18) {
        IAggregatorV3 oracle = IAggregatorV3(self.oracle);
        uint8 decimals = oracle.decimals();
        (, int256 answer,,,) = oracle.latestRoundData();

        // should panic if decimals > 18
        assert(decimals <= Constants.DECIMALS);
        UD60x18 price = ud60x18(answer.toUint256() * 10 ** (Constants.DECIMALS - decimals));

        return price;
    }
}
