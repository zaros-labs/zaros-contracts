// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { IPerpsEngine } from "./interfaces/IPerpsEngine.sol";
import { OrderModule } from "./modules/OrderModule.sol";
import { PerpsAccountModule } from "./modules/PerpsAccountModule.sol";
import { PerpsConfigurationModule } from "./modules/PerpsConfigurationModule.sol";
import { PerpsMarketModule } from "./modules/PerpsMarketModule.sol";
import { SettlementModule } from "./modules/SettlementModule.sol";

// Open Zeppelin Upgradeable dependencies
import { UUPSUpgradeable } from "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";

// __________  _____ __________ ________    _________
// \____    / /  _  \\______   \\_____  \  /   _____/
//   /     / /  /_\  \|       _/ /   |   \ \_____  \
//  /     /_/    |    \    |   \/    |    \/        \
// /_______ \____|__  /____|_  /\_______  /_______  /
//         \/       \/       \/         \/        \/

contract PerpsEngine is
    IPerpsEngine,
    OrderModule,
    PerpsAccountModule,
    PerpsConfigurationModule,
    PerpsMarketModule,
    SettlementModule,
    UUPSUpgradeable
{
    receive() external payable { }

    function initialize(
        address chainlinkForwarder,
        address chainlinkVerifier,
        address perpsAccountToken,
        address rewardDistributor,
        address usdToken,
        address liquidityEngine
    )
        external
        initializer
    {
        __Ownable_init();
        PerpsConfigurationModule.__PerpsConfigurationModule_init(
            chainlinkForwarder, chainlinkVerifier, perpsAccountToken, rewardDistributor, usdToken, liquidityEngine
        );
    }

    function _authorizeUpgrade(address) internal override onlyOwner { }
}
