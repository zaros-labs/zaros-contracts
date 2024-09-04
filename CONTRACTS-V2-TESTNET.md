Contracts V2 Testnet

————————————————————————————————————————————————————

forge script script/01_DeployPerpsEngine.s.sol --rpc-url arbitrum_sepolia --broadcast -vvvv

== Logs ==
  Trading Account NFT Implementation:  0x01d1d07bc31689cf2eBa1E8ed04F47a06A018135
  Trading Account NFT Proxy:  0x3b1a8cA6444dA93319DF19B767FCF64938641726
  UpgradeBranch:  0xF2e7B4aDfea9ec064224a4fb83399F4eDf64a740
  LookupBranch:  0xABF7447ED5D041a60d800a6811d9bf68546Aed43
  LiquidationBranch:  0x92b9d0b6A50257BDFA740D1ECE72A872115DC326
  OrderBranch:  0xC93bfcF857A4357261B60700Cff2ba7E45401559
  PerpMarketBranch:  0x716245Fd575512725F85d396dd2C31F2934BD087
  SettlementBranch:  0x7665f2F36Fc5CcE4289286BbCE9425Fd225a399e
  PerpsEngineConfigurationBranch:  0x2cB48fac215f44e59BDb700bd2c62dBE2885AeDA
  TradingAccountBranch:  0x5d7Df7c9291391539dc486Ef257F16CB592aBC41
  Perps Engine:  0x568D2BCEC9DE3A6E71E9ccd668fF1ad9654e3B18


- Update `TRADING_ACCOUNT_NFT` environment variable in the `.env` file
- Update `PERPS_ENGINE` environment variable in the `.env` file
- Update `PERPS_ENGINE` variable in the `LimitedMintingERC20.sol`

————————————————————————————————————————————————————

forge script script/testnet/DeployTestnetTokens.s.sol --rpc-url arbitrum_sepolia --broadcast -vvvv

== Logs ==
  Limited Minting ERC20 Implementation:  0x96c2c1429CE89E3C988f6936E85B8d0445577b5b
  USDC Proxy:  0x2A7cF4Fb8dfDCcdB29d06B09A9132e4f9881a4dd
  USDz Proxy:  0xEdD194BF6bc6c338a7801E35B807f25c7C382073

- Update `USDC_ADDRESS` in the `Usdc.sol`
- Update `USDZ_ADDRESS`in the `Usdz.sol`

————————————————————————————————————————————————————

forge script script/testnet/SetStartTimeMinting.s.sol --rpc-url arbitrum_sepolia --broadcast -vvvv

== Logs ==
  Start time minting set to: 1725380400

————————————————————————————————————————————————————

forge script script/02_ConfigurePerpsEngine.s.sol --sig "run(uint256,uint256)" 1 2 --rpc-url arbitrum_sepolia --broadcast -vvvv

== Logs ==
  Liquidation Keeper:  0x51b392902Cf43b13ABFAC3aCB815461B49549940

————————————————————————————————————————————————————

forge script script/03_CreatePerpMarkets.s.sol --sig "run(uint256,uint256)" 1 10 --rpc-url arbitrum_sepolia --broadcast -vvvv

== Logs ==
  MarketOrderKeeper Implementation:  0x2aF030c518acC534c27bA5F46CD163502888d890
  Market Order Keeper Deployed: Market ID:  1  Keeper Address:  0xA73dCef0904460F0c5EC78D98da8D5b6E58aCfc9
  Market Order Keeper Deployed: Market ID:  2  Keeper Address:  0x35474Ca9799Bcfba15bFdAfe07393B6be4f8301a
  Market Order Keeper Deployed: Market ID:  3  Keeper Address:  0x71e128cd8688AD24c208f06B14BEd78c1272a5Fa
  Market Order Keeper Deployed: Market ID:  4  Keeper Address:  0x447dF822195E35CDB8cE568E39e84224717B54f4
  Market Order Keeper Deployed: Market ID:  5  Keeper Address:  0x6ac4b581C1efE48007f3c675249751565Bf31112
  Market Order Keeper Deployed: Market ID:  6  Keeper Address:  0x6fAaE0e7F18773506D90353a05a8f8020547c81A
  Market Order Keeper Deployed: Market ID:  7  Keeper Address:  0xB622367bc93ef38d1b3504502063796cC6732f16
  Market Order Keeper Deployed: Market ID:  8  Keeper Address:  0xfEBDf0a009fD0A3e935590c49FFa0a5862b67D3f
  Market Order Keeper Deployed: Market ID:  9  Keeper Address:  0x214Bd106a39c03Bb54B2976Bde344efD4641EF61
  Market Order Keeper Deployed: Market ID:  10  Keeper Address:  0xd5C53C0d59EF5a2Eaa072dC5d55953a448eDd783
