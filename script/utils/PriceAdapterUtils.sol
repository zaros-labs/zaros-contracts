// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { PriceAdapter } from "@zaros/utils/PriceAdapter.sol";

// Open Zeppelin dependencies
import { ERC1967Proxy } from "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

library PriceAdapterUtils {
    function deployPriceAdapter(PriceAdapter.PriceAdapterInitializeData memory params) internal returns (address priceAdapter) {
        address priceAdapterImplementation = address(new PriceAdapter());
        bytes memory priceAdapterInitializeData = abi.encodeWithSelector(
            PriceAdapter.initialize.selector, params
        );
        priceAdapter =
            address(new ERC1967Proxy(priceAdapterImplementation, priceAdapterInitializeData));
    }
}
