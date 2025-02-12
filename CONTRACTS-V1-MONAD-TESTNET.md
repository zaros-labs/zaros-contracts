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
  Trading Account NFT Implementation:  0x67e91ec1639eF166057195a6Bc8Ed3d13C105f8A
  Trading Account NFT Proxy:  0x2CA7899519034d7039fFc8aee2de6A02662a7E5D
  Success! Deployed Trading Account Token.


  UpgradeBranch:  0xfC34D3dB6737AAd74d8366e6BFF6396c2D3ab0d4
  LookupBranch:  0x79D1c89f308c03e00Cd13fe7f9D697173882c964
  LiquidationBranch:  0xb7456F3dA7e701EaC5528093C3Fa1A027e555662
  OrderBranch:  0xf589f40e919668990f421632E55ACc1dAE6187EF
  PerpMarketBranch:  0x02e8aB09Acd8e3614981d9289140fa837Bfccd13
  SettlementBranch:  0x3444c8305b26317560C03b340D12Eb7b991B692F
  PerpsEngineConfigurationBranch:  0x8eF4713b306206df45c6Eff4C92ca7a25bEd4E10
  TradingAccountBranch:  0xa9373bFa1D14716489D5bbE77048023dBeB601ce
  **************************
  Deploying Perps Engine...
  **************************
  Perps Engine:  0x6D90B34da7e2AdCB07FDf096242875ff7941eC74
  Success! Deployed Perps Engine.
```

- Update `TRADING_ACCOUNT_NFT` environment variable in the `.env` file
- Update `PERPS_ENGINE` environment variable in the `.env` file
- Update `PERPS_ENGINE` variable in the `LimitedMintingERC20.sol`
- Update `PERPS_ENGINE` variable in the `LimitedMintingWETH.sol`
- Update `engine` params in the `script/vaults`
- Update `engine` params in the `script/perp-markets-credit-config`

————————————————————————————————————————————————————

```bash
forge script script/testnet/DeployTestnetTokens.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY  --broadcast -vvvv
```

```bash
  Limited Minting ERC20 Implementation:  0x70e290C56c2d117d2a782201F04F629BDd65FD1F
  USDC Proxy:  0x3Bb8a17d8EDCAAbC0E064500367Efc89f90A6D83
  USD Token Proxy:  0xbaDF69305038a4E009f79416340B7f4Bc5ea7a6b
  wEth:  0x03bEad4f3D886f0632b92F6f913358Feb765978E
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
- Update `USD_TOKEN` params in the `script/perp-markets-credit-config`

————————————————————————————————————————————————————

```bash
forge script script/testnet/SetStartTimeMinting.s.sol --sig "run(address)" 0x3Bb8a17d8EDCAAbC0E064500367Efc89f90A6D83 --rpc-url $RPC_URL --private-key $PRIVATE_KEY  --broadcast -vvvv
```

```bash
  Start time minting set to:  1725380400
```

```bash
forge script script/testnet/SetStartTimeMinting.s.sol --sig "run(address)" 0xbaDF69305038a4E009f79416340B7f4Bc5ea7a6b --rpc-url $RPC_URL --private-key $PRIVATE_KEY  --broadcast -vvvv
```

```bash
  Start time minting set to:  1725380400
```

```bash
forge script script/testnet/SetStartTimeMinting.s.sol --sig "run(address)" 0x03bEad4f3D886f0632b92F6f913358Feb765978E --rpc-url $RPC_URL --private-key $PRIVATE_KEY  --broadcast -vvvv
```

```bash
  Start time minting set to:  1725380400
```

————————————————————————————————————————————————————

```bash
forge script script/02_DeployMarketMakingEngine.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY  --broadcast -vvvv
```

```bash
  UpgradeBranch:  0x2006842C83b814878a4E2745b51AF386992B7151
  CreditDelegationBranch:  0x1eC4BA61B28B82935d774a7b4bc32Fd7655f19C8
  MarketMakingEnginConfigBranch:  0xaE6c9Dd6DCF829e7A7D4ab0B5A0220560ED91912
  VaultRouterBranch:  0x41C6C3E7b5522aaf4e6dd4466CD534Da593E3611
  FeeDistributionBranch:  0xA5149CF20833eD276Bb2A9d19a76694d8a981014
  StabilityBranch:  0x0CF1B406557eb1A2753fA326D1C9DE65fa78Cdf8
  **************************
  Deploying Market Making Engine...
  **************************
  Success! Market Making Engine:
  0xE8d7e85E5a27B1C9C098Ba8D0F1a153813172eCf
```

- Update `MARKET_MAKING_ENGINE` in the .env

————————————————————————————————————————————————————

```bash
forge script script/03_DeployAndConfigureReferralModule.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY  --broadcast -vvvv
```

```bash
  **************************
  Environment variables:
  Market Making Engine:  0xE8d7e85E5a27B1C9C098Ba8D0F1a153813172eCf
  Perps Engine:  0xE8d7e85E5a27B1C9C098Ba8D0F1a153813172eCf
  **************************
  **************************
  Deploy and configuring referral modules...
  **************************
  Referral Module deployed at: 0x92421bAaabf45805aDcb273CD5B95Bac4e3dD916
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
  Trading Account Token:  0x2CA7899519034d7039fFc8aee2de6A02662a7E5D
  Perps Engine:  0x6D90B34da7e2AdCB07FDf096242875ff7941eC74
  Market Making Engine:  0xE8d7e85E5a27B1C9C098Ba8D0F1a153813172eCf
  Usd Token:  0xbaDF69305038a4E009f79416340B7f4Bc5ea7a6b
  Liquidation Keeper:  0xB5F9c677AE9E92B52F27c096A506d6d3725C65b3
  Referral Module:  0x92421bAaabf45805aDcb273CD5B95Bac4e3dD916
  **************************
  USDC/USD Zaros Price Adapter - PriceAdapter deployed at: 0xD6AD9610075C4cC09f3048490E2aF40B9C43938d
  USDz/USD Zaros Price Adapter - PriceAdapter deployed at: 0xAC3624363e36d73526B06D33382cbFA9637318C3
  WETH/USD Zaros Price Adapter - PriceAdapter deployed at: 0x63BbF16F9813470ED12A8C2Bf1565235b7262D43
  WEETH/USD Zaros Price Adapter - PriceAdapter deployed at: 0x44499049411D54D3D853E4ea44283237c336CC4A
  WBTC/USD Zaros Price Adapter - PriceAdapter deployed at: 0x33724F7A64fFC7393cC5472a4515F0057c878A0c
  WSTETH/USD Zaros Price Adapter - PriceAdapter deployed at: 0xE8f84e46ae7Cc30B7a23611Ef29C2FC1ed7618d1
  **************************
  Configuring liquidators...
  **************************
  Success! Liquidator address:
  0xB5F9c677AE9E92B52F27c096A506d6d3725C65b3
  **************************
  Configuring USD Token token...
  **************************
  Success! USD Token token address:
  0xbaDF69305038a4E009f79416340B7f4Bc5ea7a6b
  **************************
  Configuring trading account token...
  **************************
  Success! Trading account token address:
  0x2CA7899519034d7039fFc8aee2de6A02662a7E5D
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
  Perps Engine:  0x6D90B34da7e2AdCB07FDf096242875ff7941eC74
  Chainlink Verifier:  0x2ff010DEbC1297f19579B4246cad07bd24F2488A
  CONSTANS:
  OFFCHAIN_ORDERS_KEEPER_ADDRESS:  0x3a8fD90D680D9649DE85922CF6D6A4f57Bb8d1D5
  **************************
  BTC/USD Zaros Price Adapter - PriceAdapter deployed at: 0x793bda0e8C1d0982D2f8fCfE267F401A7DF5258d
  ETH/USD Zaros Price Adapter - PriceAdapter deployed at: 0x83411736C107cfFDB6042a2c22BE93350C5Bc3F4
  LINK/USD Zaros Price Adapter - PriceAdapter deployed at: 0x8D7dc4a536069f8c05F9ECeaFde047583245c90E
  ARB/USD Zaros Price Adapter - PriceAdapter deployed at: 0xdD74abCcFcDa0518c2a64E181F3C90b16F25276D
  BNB/USD Zaros Price Adapter - PriceAdapter deployed at: 0x6D0349EADeBAD56A789E338DEb31AA3eb3F93De1
  DOGE/USD Zaros Price Adapter - PriceAdapter deployed at: 0x3C1Ca7092D697dB9c597412dd73057320d24735d
  SOL/USD Zaros Price Adapter - PriceAdapter deployed at: 0xFAc9BdC1D89e7C8b952d9b2A3360B3BB27635974
  MATIC/USD Zaros Price Adapter - PriceAdapter deployed at: 0xCB1889681B0C48998A662B86d660815E3ecdeD1F
  LTC/USD Zaros Price Adapter - PriceAdapter deployed at: 0x831548eFC746E7273E9D8794FCAb0AaC0a0F37E4
  FTM/USD Zaros Price Adapter - PriceAdapter deployed at: 0x5459BabCd23317943D125aB02ce9d327CB63c7Ee
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
  Market Making Engine:  0xE8d7e85E5a27B1C9C098Ba8D0F1a153813172eCf
  Perps Engine:  0xE8d7e85E5a27B1C9C098Ba8D0F1a153813172eCf
  Perps Engine Usd Token:  0xbaDF69305038a4E009f79416340B7f4Bc5ea7a6b
  Chainlink Verifier:  0x498463F50Edab30c7B1c828031D1Bdcf12607DD2
  wEth:  0x03bEad4f3D886f0632b92F6f913358Feb765978E
  USDC:  0x3Bb8a17d8EDCAAbC0E064500367Efc89f90A6D83
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


  Collateral:  0x3Bb8a17d8EDCAAbC0E064500367Efc89f90A6D83
  Price Adapter:  0xD6AD9610075C4cC09f3048490E2aF40B9C43938d
  Credit ratio:  1000000000000000000
  Is enabled:  true
  Decimals:  18
  Success! Configured collateral:


  Collateral:  0x03bEad4f3D886f0632b92F6f913358Feb765978E
  Price Adapter:  0x63BbF16F9813470ED12A8C2Bf1565235b7262D43
  Credit ratio:  1000000000000000000
  Is enabled:  true
  Decimals:  18
  **************************
  Configuring system keepers...
  **************************
  Success! Configured system keeper:
  0x6D90B34da7e2AdCB07FDf096242875ff7941eC74
  Success! Configured system keeper:
  0xE2658E63c85D8a469324afA377Bf5694cd55bD7B
  **************************
  Configuring engines...
  **************************
  Success! Configured engine:
  Engine:  0x6D90B34da7e2AdCB07FDf096242875ff7941eC74
  Usd Token:  0xbaDF69305038a4E009f79416340B7f4Bc5ea7a6b
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
  0x03bEad4f3D886f0632b92F6f913358Feb765978E
  **************************
  Configuring USDC...
  **************************
  Success! Configured USDC:
  0x3Bb8a17d8EDCAAbC0E064500367Efc89f90A6D83
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
  Market Making Engine:  0xE8d7e85E5a27B1C9C098Ba8D0F1a153813172eCf
  wEth:  0x03bEad4f3D886f0632b92F6f913358Feb765978E
  USDC:  0x3Bb8a17d8EDCAAbC0E064500367Efc89f90A6D83
  shouldDeployMock:  true
  uniswapV3SwapStrategyRouter:  0x361F3efcDae4B8A3613D4924F6D934A64187Aa7F
  uniswapV2SwapStrategyRouter:  0xECd27558CfC5e013b2CD3f4D7c8F153E48Bc5Fac
  curveSwapStrategyRouter:  0x7D9817e7CE7BDc66fB6509F3bcE0F54f6D38889F
  CONSTANTS:
  SLIPPAGE_TOLERANCE_BPS:  100
  **************************
  **************************
  Configuring Uniswap V3 Adapter...
  **************************
  UniswapV3Adapter deployed at: 0x10809d1c5EeE0b0C16aE91C16b55855cF5c8bc39
  Asset swap config data set in UniswapV3Adapter: asset: 0x3Bb8a17d8EDCAAbC0E064500367Efc89f90A6D83, decimals: 18, priceAdapter: 0xD6AD9610075C4cC09f3048490E2aF40B9C43938d
  Asset swap config data set in UniswapV3Adapter: asset: 0x03bEad4f3D886f0632b92F6f913358Feb765978E, decimals: 18, priceAdapter: 0x63BbF16F9813470ED12A8C2Bf1565235b7262D43
  Uniswap V3 Swap Strategy configured in MarketMakingEngine: strategyId: 1, strategyAddress: 0x10809d1c5EeE0b0C16aE91C16b55855cF5c8bc39
  Success! Uniswap V3 Adapter configured.


  **************************
  Configuring Uniswap V2 Adapter...
  **************************
  UniswapV2Adapter deployed at: 0x1638d716c77903DE9c9cF02eee8A5154535022e5
  Asset swap config data set in UniswapV2Adapter: asset: 0x3Bb8a17d8EDCAAbC0E064500367Efc89f90A6D83, decimals: 18, priceAdapter: 0xD6AD9610075C4cC09f3048490E2aF40B9C43938d
  Asset swap config data set in UniswapV2Adapter: asset: 0x03bEad4f3D886f0632b92F6f913358Feb765978E, decimals: 18, priceAdapter: 0x63BbF16F9813470ED12A8C2Bf1565235b7262D43
  Uniswap V2 Swap Strategy configured in MarketMakingEngine: strategyId: 2, strategyAddress: 0x1638d716c77903DE9c9cF02eee8A5154535022e5
  Success! Uniswap V2 Adapter configured.


  **************************
  Configuring Curve Adapter...
  **************************
  CurveAdapter deployed at: 0x53f37fC989e663563Dc5798d09e7A2929afe373F
  Asset swap config data set in CurveAdapter: asset: 0x3Bb8a17d8EDCAAbC0E064500367Efc89f90A6D83, decimals: 18, priceAdapter: 0xD6AD9610075C4cC09f3048490E2aF40B9C43938d
  Asset swap config data set in CurveAdapter: asset: 0x03bEad4f3D886f0632b92F6f913358Feb765978E, decimals: 18, priceAdapter: 0x63BbF16F9813470ED12A8C2Bf1565235b7262D43
  Curve Swap Strategy configured in MarketMakingEngine: strategyId: 3, strategyAddress: 0x7D9817e7CE7BDc66fB6509F3bcE0F54f6D38889F
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
  Market Making Engine:  0xE8d7e85E5a27B1C9C098Ba8D0F1a153813172eCf
  **************************
  **************************
  Configuring Vaults...
  **************************
  Vault id 16 index token 0x93AaB91F25Ea6bdCb4dA389540d7eDbb0768A88b decimals 18
  Usd Token Swap Keeper deployed at: 0xC10De51EAC5e796541d742b881AaC72509cd3335, asset: 0x3Bb8a17d8EDCAAbC0E064500367Efc89f90A6D83, streamIdString: 0x00038f83323b6b08116d1614cf33a9bd71ab5e0abf0c9f1b783a74a43e7bd992
  Vault id 17 index token 0xa351986a232ce3f35698f823f5404E339a67680A decimals 18
  Usd Token Swap Keeper deployed at: 0x999b1B1a095d824A1fBdFB04E4F7BB292B65cAe2, asset: 0x03bEad4f3D886f0632b92F6f913358Feb765978E, streamIdString: 0x000362205e10b3a147d02792eccee483dca6c7b44ecce7012cb8c6e0b68b3ae9
  Success! Vaults configured.
```

————————————————————————————————————————————————————

forge script script/TestMonadTestnet.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY  --broadcast -vvvv

forge script script/testnet/UpgradeBranches.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY  --broadcast -vvvv

forge script script/testnet/UpgradeUUPS.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY  --broadcast -vvvv
