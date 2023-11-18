// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { Constants } from "@zaros/utils/Constants.sol";
import { FeatureFlagModule } from "@zaros/utils/modules/FeatureFlagModule.sol";
import { FeatureFlag } from "@zaros/utils/storage/FeatureFlag.sol";
import { IZarosUSD } from "./interfaces/IZarosUSD.sol";

// Open Zeppelin dependencies
import { Ownable } from "@openzeppelin/access/Ownable.sol";
import { ERC20, ERC20Permit } from "@openzeppelin/token/ERC20/extensions/ERC20Permit.sol";

contract ZarosUSD is IZarosUSD, ERC20Permit, Ownable, FeatureFlagModule {
    constructor() ERC20("Zaros USD", "USDz") ERC20Permit("Zaros USD") { }

    function mint(address to, uint256 amount) external {
        FeatureFlag.ensureAccessToFeature(Constants.MINT_FEATURE_FLAG);
        _requireAmountNotZero(amount);
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        FeatureFlag.ensureAccessToFeature(Constants.BURN_FEATURE_FLAG);
        _requireAmountNotZero(amount);
        _burn(from, amount);
    }

    function _requireAmountNotZero(uint256 amount) private pure {
        if (amount == 0) {
            revert ZarosUSD_ZeroAmount();
        }
    }
}
