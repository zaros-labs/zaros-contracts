Contracts V1 Monad Testnet

————————————————————————————————————————————————————

```bash
forge script script/01_DeployPerpsEngine.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY  --broadcast -vvvv
```

```bash
  **************************
  Environment variables:
  isTestnet:  true
  **************************
  **************************
  Deploying Trading Account Token...
  **************************
  Trading Account NFT Implementation:  0xAB56042276a1F94524d7693fDA35ab40CCA53BA7
  Trading Account NFT Proxy:  0x1835F3b383DAb01f7dA9bFEc1A8448186CC21DF4
  Success! Deployed Trading Account Token.


  UpgradeBranch:  0x9e1a52E77aa70eBf90c08Ad58172367a836F6f94
  LookupBranch:  0xeD22E3f8F30f8699773717d53997B16074838505
  LiquidationBranch:  0x008F81Db74818296298560B09e49e842BE15C611
  OrderBranch:  0x923B3A497E1B49B1bF28CC0BEE72e1695852f970
  PerpMarketBranch:  0x1e02b61886887d2326E93Ae809EF230c0dDb3cb5
  SettlementBranch:  0xa7f52E24D56074FC3c23157C96Ad8a9624523BF0
  PerpsEngineConfigurationBranch:  0xCbbeb257D3711Ad5CaDE3798E9EaCfbC9d9F0768
  TradingAccountBranch:  0x8546dD49C00675A9a9c6d6058190C5b9F864bC69
  **************************
  Deploying Perps Engine...
  **************************
  Perps Engine:  0xd837cB495761D5bC5Bfa7d5dE876C0407E04Ae08
  Success! Deployed Perps Engine.
```

- Update `TRADING_ACCOUNT_NFT` environment variable in the `.env` file
- Update `PERPS_ENGINE` environment variable in the `.env` file
- Update `PERPS_ENGINE` variable in the `LimitedMintingERC20.sol`
- Update `PERPS_ENGINE` variable in the `LimitedMintingWETH.sol`
- Update `engine` params in the `script/vaults`

————————————————————————————————————————————————————

```bash
forge script script/testnet/DeployTestnetTokens.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY  --broadcast -vvvv
```

```bash
  Limited Minting ERC20 Implementation:  0x316357370943B3e6312810d4c64Cc4F1276aD535
  USDC Proxy:  0x4470E455Aa0a43BA885B6F91bfC9FcEeDB9Dd083
  USD Token Proxy:  0x1Edcf2dce6657E509817AFC5d9842550E252af02
  wEth:  0xBa6187ea9023Ca2EAF8B9D46690f3937EFdDA7c2
```

- Update `USDC_MONAD_TESTNET_ADDRESS` in the `Usdc.sol`
- Update `USD_TOKEN_MONAD_TESTNET_ADDRESS`in the `UsdToken.sol`
- Update `USDC` environment variable in the `.env` file
- Update `USD_TOKEN` environment variable in the `.env` file
- Update `WETH` environment variable in the `.env` file
- Update `USDC_MONAD_TESTNET_MARKET_MAKING_ENGINE_ADDRESS` in the `Usdc.sol`
- Update `WETH_MONAD_TESTNET_MARKET_MAKING_ENGINE_ADDRESS` in the `WEth.sol`
- Update all `USDC` address in the `script/vaults`
- Update all `wEth` address in the `script/vaults`

————————————————————————————————————————————————————

```bash
forge script script/testnet/SetStartTimeMinting.s.sol --sig "run(address)" 0x4470E455Aa0a43BA885B6F91bfC9FcEeDB9Dd083 --rpc-url $RPC_URL --private-key $PRIVATE_KEY  --broadcast -vvvv
```

```bash
  Start time minting set to:  1725380400
```

```bash
forge script script/testnet/SetStartTimeMinting.s.sol --sig "run(address)" 0x1Edcf2dce6657E509817AFC5d9842550E252af02 --rpc-url $RPC_URL --private-key $PRIVATE_KEY  --broadcast -vvvv
```

```bash
  Start time minting set to:  1725380400
```

```bash
forge script script/testnet/SetStartTimeMinting.s.sol --sig "run(address)" 0xBa6187ea9023Ca2EAF8B9D46690f3937EFdDA7c2 --rpc-url $RPC_URL --private-key $PRIVATE_KEY  --broadcast -vvvv
```

```bash
  Start time minting set to:  1725380400
```

————————————————————————————————————————————————————

```bash
forge script script/02_DeployMarketMakingEngine.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY  --broadcast -vvvv
```

```bash
  UpgradeBranch:  0x4799D15224226eB4343e345d35A6eFf1Afacf2de
  CreditDelegationBranch:  0x0aB542F291084F7f4D6840F69a7eD85c3Fa46931
  MarketMakingEnginConfigBranch:  0x633Dfa90d27e0F278a7577Bd626E18Fa503F57bf
  VaultRouterBranch:  0xB12F99E4F9186c1d1761B98915Af0034E522E293
  FeeDistributionBranch:  0xC09b60C428b3C39075aFda31d638377cd63E4a04
  StabilityBranch:  0x0CF467684832143b31BE39cA0a68b9cBa6fDFbAD
  **************************
  Deploying Market Making Engine...
  **************************
  Success! Market Making Engine:
  0xeEa3aa73705DA5086838Df65a14001a43168E8DA
```

- Update `MARKET_MAKING_ENGINE` in the .env

————————————————————————————————————————————————————

```bash
forge script script/03_DeployAndConfigureReferralModule.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY  --broadcast -vvvv
```

```bash
  **************************
  Environment variables:
  Market Making Engine:  0xeEa3aa73705DA5086838Df65a14001a43168E8DA
  Perps Engine:  0xeEa3aa73705DA5086838Df65a14001a43168E8DA
  **************************
  **************************
  Deploy and configuring referral modules...
  **************************
  Referral Module deployed at: 0xE4490b6E959dd45Fa78191ed973a9DcB8efE22d6
  Success! Deployed and configured Referral Module
```

- Update `REFERRAL_MODULE` in the .env

————————————————————————————————————————————————————

```bash
forge script script/04_ConfigurePerpsEngine.s.sol --sig "run(uint256,uint256)" 1 2 --rpc-url $RPC_URL --private-key $PRIVATE_KEY  --broadcast -vvvv
```

```bash
  **************************
  Environment variables:
  Trading Account Token:  0x1835F3b383DAb01f7dA9bFEc1A8448186CC21DF4
  Perps Engine:  0xd837cB495761D5bC5Bfa7d5dE876C0407E04Ae08
  Market Making Engine:  0xeEa3aa73705DA5086838Df65a14001a43168E8DA
  Usd Token:  0x1Edcf2dce6657E509817AFC5d9842550E252af02
  Liquidation Keeper:  0xB5F9c677AE9E92B52F27c096A506d6d3725C65b3
  Referral Module:  0xE4490b6E959dd45Fa78191ed973a9DcB8efE22d6
  **************************
  USDC/USD Zaros Price Adapter - PriceAdapter deployed at: 0x24c04E6Aa405EDB4e3847049dE459f8304145038
  USDz/USD Zaros Price Adapter - PriceAdapter deployed at: 0x12D8f9731bBba559f76A952f47b374A16263Ec63
  WETH/USD Zaros Price Adapter - PriceAdapter deployed at: 0x81a2E5702167afAB2bbdF9c781f74160Ae433fA5
  WEETH/USD Zaros Price Adapter - PriceAdapter deployed at: 0xa6a34AD9fe29902C53Ca3862667a1EA7E6ff6e13
  WBTC/USD Zaros Price Adapter - PriceAdapter deployed at: 0xC8e84af129FF5c5CB0bcE9a1972311feB4e392F9
  WSTETH/USD Zaros Price Adapter - PriceAdapter deployed at: 0x8Cbc9A29f2Ae01F420DaAb8DcbF21131337a38E4
  **************************
  Configuring liquidators...
  **************************
  Success! Liquidator address:
  0xB5F9c677AE9E92B52F27c096A506d6d3725C65b3
  **************************
  Configuring USD Token token...
  **************************
  Success! USD Token token address:
  0x1Edcf2dce6657E509817AFC5d9842550E252af02
  **************************
  Configuring trading account token...
  **************************
  Success! Trading account token address:
  0x1835F3b383DAb01f7dA9bFEc1A8448186CC21DF4
  **************************
  Transferring Trading Account Token ownership to the perps engine...
  **************************
  Success! Trading Account Token token ownership transferred to the perps engine.
```

- Update all `USDC` price adapters
- Update all `USD TOKEN` price adapters
- Update all `WETH` price adapters
- Update all `WEETH` price adapters
- Update all `WBTC` price adapters
- Update all `WSTETH` price adapters

————————————————————————————————————————————————————

```bash
forge script script/05_CreatePerpMarkets.s.sol --sig "run(uint256,uint256,bool,address)" 1 10 true 0x8D9a0B9F3C11Bad4FFfD18cEe758a91F109945A9 --rpc-url $RPC_URL --private-key $PRIVATE_KEY  --broadcast -vvvv
```

```bash
  **************************
  Environment variables:
  Perps Engine:  0xd837cB495761D5bC5Bfa7d5dE876C0407E04Ae08
  Chainlink Verifier:  0x2ff010DEbC1297f19579B4246cad07bd24F2488A
  CONSTANS:
  OFFCHAIN_ORDERS_KEEPER_ADDRESS:  0x3a8fD90D680D9649DE85922CF6D6A4f57Bb8d1D5
  **************************
  BTC/USD Zaros Price Adapter - PriceAdapter deployed at: 0x58405B3872067ddf78e3157664DAD02ad0337c11
  ETH/USD Zaros Price Adapter - PriceAdapter deployed at: 0x94855D8CE505a0C600a3Aac2C544489A8B85559b
  LINK/USD Zaros Price Adapter - PriceAdapter deployed at: 0x464edaF81b40576bBab4768aD76c81d3cf629c35
  ARB/USD Zaros Price Adapter - PriceAdapter deployed at: 0xEf6f11C8035e7aDaA53E90747E582d696C41ad92
  BNB/USD Zaros Price Adapter - PriceAdapter deployed at: 0xBA4eEB7116E7779056f4bc19Da624f50c75dFA4C
  DOGE/USD Zaros Price Adapter - PriceAdapter deployed at: 0x81Bd5B84639C12bd2D78C7CdAF57b7CC0333B355
  SOL/USD Zaros Price Adapter - PriceAdapter deployed at: 0xa289031Cc94717b5991604f490830Cc9FA4C78b1
  MATIC/USD Zaros Price Adapter - PriceAdapter deployed at: 0xA3A1FFd14d844AE063721178cC3Da14B1c0d7A57
  LTC/USD Zaros Price Adapter - PriceAdapter deployed at: 0xD2be448419F3A71563a928c13039655aB0cd1dEd
  FTM/USD Zaros Price Adapter - PriceAdapter deployed at: 0x6f27Ce1Ce4F36389F248CD1ceC08A0d3a1c2aA4E
  **************************
  Creating Perp Markets...
  **************************
  Market Order Keeper Deployed: Market ID:  1  Keeper Address:  0x8D9a0B9F3C11Bad4FFfD18cEe758a91F109945A9
  Market Order Keeper Deployed: Market ID:  2  Keeper Address:  0x8D9a0B9F3C11Bad4FFfD18cEe758a91F109945A9
  Market Order Keeper Deployed: Market ID:  3  Keeper Address:  0x8D9a0B9F3C11Bad4FFfD18cEe758a91F109945A9
  Market Order Keeper Deployed: Market ID:  4  Keeper Address:  0x8D9a0B9F3C11Bad4FFfD18cEe758a91F109945A9
  Market Order Keeper Deployed: Market ID:  5  Keeper Address:  0x8D9a0B9F3C11Bad4FFfD18cEe758a91F109945A9
  Market Order Keeper Deployed: Market ID:  6  Keeper Address:  0x8D9a0B9F3C11Bad4FFfD18cEe758a91F109945A9
  Market Order Keeper Deployed: Market ID:  7  Keeper Address:  0x8D9a0B9F3C11Bad4FFfD18cEe758a91F109945A9
  Market Order Keeper Deployed: Market ID:  8  Keeper Address:  0x8D9a0B9F3C11Bad4FFfD18cEe758a91F109945A9
  Market Order Keeper Deployed: Market ID:  9  Keeper Address:  0x8D9a0B9F3C11Bad4FFfD18cEe758a91F109945A9
  Market Order Keeper Deployed: Market ID:  10  Keeper Address:  0x8D9a0B9F3C11Bad4FFfD18cEe758a91F109945A9
  Success! Created Perp Markets
```

————————————————————————————————————————————————————

```bash
forge script script/06_ConfigureMarketMakingEngine.s.sol --sig "run(uint256,uint256,bool)" 1 2 true --rpc-url $RPC_URL --private-key $PRIVATE_KEY  --broadcast -vvvv
```

```bash
  useMockChainlinkVerifier: true
  **************************
  Environment variables:
  Market Making Engine:  0xeEa3aa73705DA5086838Df65a14001a43168E8DA
  Perps Engine:  0xeEa3aa73705DA5086838Df65a14001a43168E8DA
  Perps Engine Usd Token:  0x1Edcf2dce6657E509817AFC5d9842550E252af02
  Chainlink Verifier:  0x410Cac11875B7962Deb9bEF0543330157B4DC789
  wEth:  0xBa6187ea9023Ca2EAF8B9D46690f3937EFdDA7c2
  USDC:  0x4470E455Aa0a43BA885B6F91bfC9FcEeDB9Dd083
  CONSTANTS:
  MSIG_ADDRESS:  0xE2658E63c85D8a469324afA377Bf5694cd55bD7B
  MSIG_SHARES_FEE_RECIPIENT:  300000000000000000
  MAX_VERIFICATION_DELAY:  60
  INITIAL_PERP_MARKET_CREDIT_CONFIG_ID:  1
  FINAL_PERP_MARKET_CREDIT_CONFIG_ID:  10
  **************************
  **************************
  Configuring vault deposit and redeem fee recipient...
  **************************
  Success! Vault deposit and redeem fee recipient:
  0xE2658E63c85D8a469324afA377Bf5694cd55bD7B
  **************************
  Configuring collaterals...
  **************************
  Success! Configured collateral:


  Collateral:  0x4470E455Aa0a43BA885B6F91bfC9FcEeDB9Dd083
  Price Adapter:  0x24c04E6Aa405EDB4e3847049dE459f8304145038
  Credit ratio:  1000000000000000000
  Is enabled:  true
  Decimals:  6
  Success! Configured collateral:


  Collateral:  0xBa6187ea9023Ca2EAF8B9D46690f3937EFdDA7c2
  Price Adapter:  0x81a2E5702167afAB2bbdF9c781f74160Ae433fA5
  Credit ratio:  1000000000000000000
  Is enabled:  true
  Decimals:  18
  **************************
  Configuring system keepers...
  **************************
  Success! Configured system keeper:
  0xd837cB495761D5bC5Bfa7d5dE876C0407E04Ae08
  Success! Configured system keeper:
  0xE2658E63c85D8a469324afA377Bf5694cd55bD7B
  **************************
  Configuring engines...
  **************************
  Success! Configured engine:
  Engine:  0xd837cB495761D5bC5Bfa7d5dE876C0407E04Ae08
  Usd Token:  0x1Edcf2dce6657E509817AFC5d9842550E252af02
  **************************
  Configuring fee recipients...
  **************************
  Success! Configured fee recipients:
  Fee Recipient:  0xE2658E63c85D8a469324afA377Bf5694cd55bD7B
  Shares:  300000000000000000
  **************************
  Configuring wEth...
  **************************
  Success! Configured wEth:
  0xBa6187ea9023Ca2EAF8B9D46690f3937EFdDA7c2
  **************************
  Configuring USDC...
  **************************
  Success! Configured USDC:
  0x4470E455Aa0a43BA885B6F91bfC9FcEeDB9Dd083
  **************************
  Transferring USD Token ownership to the market making engine...
  **************************
  Success! USD Token token ownership transferred to the market making engine.
  **************************
  Configuring Market Making Engine allowance...
  **************************
  Success! Configured Market Making Engine allowance
  **************************
  Configuring Market Making Engine Stability Configuration...
  **************************
  Success! Configured Market Making Engine Stability Configuration
  **************************
  Configuring Markets...
  **************************
  Success! Configured Markets
```

————————————————————————————————————————————————————

```bash
forge script script/07_ConfigureDexAdapters.s.sol --sig "run(bool)" true --rpc-url $RPC_URL --private-key $PRIVATE_KEY  --broadcast -vvvv
```

```bash
  **************************
  Environment variables:
  Market Making Engine:  0xeEa3aa73705DA5086838Df65a14001a43168E8DA
  wEth:  0xBa6187ea9023Ca2EAF8B9D46690f3937EFdDA7c2
  USDC:  0x4470E455Aa0a43BA885B6F91bfC9FcEeDB9Dd083
  shouldDeployMock:  true
  uniswapV3SwapStrategyRouter:  0xb2E1Fd207aD50b48223AB586553615Af1fBC3702
  uniswapV2SwapStrategyRouter:  0xee18C7f171293b474b7033f58236cd8926cA9E13
  curveSwapStrategyRouter:  0x37f250b25E521B6B7b2bC027229B5C827C336183
  CONSTANTS:
  SLIPPAGE_TOLERANCE_BPS:  100
  **************************
  **************************
  Configuring Uniswap V3 Adapter...
  **************************
  UniswapV3Adapter deployed at: 0x99D234489C47864db177E0e0318171CDE63BAA15
  Asset swap config data set in UniswapV3Adapter: asset: 0x4470E455Aa0a43BA885B6F91bfC9FcEeDB9Dd083, decimals: 6, priceAdapter: 0x24c04E6Aa405EDB4e3847049dE459f8304145038
  Asset swap config data set in UniswapV3Adapter: asset: 0xBa6187ea9023Ca2EAF8B9D46690f3937EFdDA7c2, decimals: 18, priceAdapter: 0x81a2E5702167afAB2bbdF9c781f74160Ae433fA5
  Uniswap V3 Swap Strategy configured in MarketMakingEngine: strategyId: 1, strategyAddress: 0x99D234489C47864db177E0e0318171CDE63BAA15
  Success! Uniswap V3 Adapter configured.


  **************************
  Configuring Uniswap V2 Adapter...
  **************************
  UniswapV2Adapter deployed at: 0x852a1A34BB70711250D44603678Da5DD07333Fb3
  Asset swap config data set in UniswapV2Adapter: asset: 0x4470E455Aa0a43BA885B6F91bfC9FcEeDB9Dd083, decimals: 6, priceAdapter: 0x24c04E6Aa405EDB4e3847049dE459f8304145038
  Asset swap config data set in UniswapV2Adapter: asset: 0xBa6187ea9023Ca2EAF8B9D46690f3937EFdDA7c2, decimals: 18, priceAdapter: 0x81a2E5702167afAB2bbdF9c781f74160Ae433fA5
  Uniswap V2 Swap Strategy configured in MarketMakingEngine: strategyId: 2, strategyAddress: 0x852a1A34BB70711250D44603678Da5DD07333Fb3
  Success! Uniswap V2 Adapter configured.


  **************************
  Configuring Curve Adapter...
  **************************
  CurveAdapter deployed at: 0x4527758DDcd442F3ED72e1ADf53148A4Fd3dbc9a
  Asset swap config data set in CurveAdapter: asset: 0x4470E455Aa0a43BA885B6F91bfC9FcEeDB9Dd083, decimals: 6, priceAdapter: 0x24c04E6Aa405EDB4e3847049dE459f8304145038
  Asset swap config data set in CurveAdapter: asset: 0xBa6187ea9023Ca2EAF8B9D46690f3937EFdDA7c2, decimals: 18, priceAdapter: 0x81a2E5702167afAB2bbdF9c781f74160Ae433fA5
  Curve Swap Strategy configured in MarketMakingEngine: strategyId: 3, strategyAddress: 0x37f250b25E521B6B7b2bC027229B5C827C336183
  Success! Curve Adapter configured.
```

————————————————————————————————————————————————————

```bash
forge script script/08_CreateVaults.s.sol --sig "run(uint256,uint256)" 16 17 --rpc-url $RPC_URL --private-key $PRIVATE_KEY  --broadcast -vvvv
```

```bash
== Logs ==
  **************************
  Environment variables:
  Market Making Engine:  0xeEa3aa73705DA5086838Df65a14001a43168E8DA
  **************************
  **************************
  Configuring Vaults...
  **************************
  Usd Token Swap Keeper deployed at: 0x364F8635d203C6375DbCd4B4bC4AEFE98fB1069D, asset: 0x4470E455Aa0a43BA885B6F91bfC9FcEeDB9Dd083, streamIdString: 0x00038f83323b6b08116d1614cf33a9bd71ab5e0abf0c9f1b783a74a43e7bd992
  Usd Token Swap Keeper deployed at: 0xfBAD2740d20dC32C9288Ddfdd1df756D1D9aFB5D, asset: 0xBa6187ea9023Ca2EAF8B9D46690f3937EFdDA7c2, streamIdString: 0x000362205e10b3a147d02792eccee483dca6c7b44ecce7012cb8c6e0b68b3ae9
  Success! Vaults configured.
```

————————————————————————————————————————————————————
