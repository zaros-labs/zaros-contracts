# Zaros

- [About](#about)
- [Tree Proxy Pattern](#tree-proxy-pattern)
- [Getting Started](#getting-started)
  - [Requirements](#requirements)
  - [Installation](#installation)
  - [Quickstart](#quickstart)
- [Usage](#usage)
  - [Coverage](#coverage)
- [Audit Scope Details](#audit-scope-details)
  - [Roles](#roles)
  - [Known Issues](#known-issues)


# About

Zaros is a Perpetuals DEX powered by Boosted (Re)Staking Vaults. Whether you're a seasoned trader or new to the world of cryptocurrencies, Zaros is here to maximize your trading potential and enhance your yields on Arbitrum (and soon on Monad).

Zaros connects Liquid Re(Staking) Tokens (LSTs & LRTs) with Perpetual Futures, offering opportunities to amplify your yield through our innovative ZLP Vaults. With the ability to trade with leverage of up to 100x, our platform empowers you to take control of your investments like never before.

Zaros Gitbook: https://docs.zaros.fi/overview

# Tree Proxy Pattern

## Zaros Protocol's novel Architecture - Tree Proxy Pattern

Tree Proxy Pattern is our novel modular, and opinionated proxy pattern solution designed to address the complexity and often confusing terminology that programmers encounter in large smart contract system patterns, such as the EIP-2535 Diamond Standard. This pattern is still in a preliminary version.

We've observed that terms like “diamond” for a proxy contract and “facet” for an implementation can create barriers to understanding and efficiency. Our approach simplifies this by leveraging the familiar concept of a tree, widely recognized and understood within the development community from basic Data Structures to more advanced topics.

Documentation: https://docs.zaros.fi/overview/getting-started/tree-proxy-pattern

# Getting Started

## Requirements

- [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
  - You'll know you did it right if you can run `git --version` and you see a response like `git version x.x.x`
- [foundry](https://getfoundry.sh/)
  - You'll know you did it right if you can run `forge --version` and you see a response like `forge 0.2.0 (816e00b 2023-03-16T00:05:26.396218Z)`
<!-- Additional requirements here -->

## Installation

```bash
git clone git@github.com:zaros-labs/zaros-core.git
cd zaros-core
make
```

## Quickstart

```bash
make test
```

# Usage

## Coverage

```bash
forge test --report debug
```

# Audit Scope Details

- Commit Hash: XXX
- Files in scope:
```
make scope
```
- Solc Version: 0.8.25
- Chain(s) to deploy to:
  - Arbitrum Sepolia
- ERC20 Token Compatibilities:
  - None

## Roles

- Role1: <!-- Description -->

## Known Issues

- Issue1: <!-- Description -->

# Latest deployments:

### Arbitrum Sepolia:

- (LimitedMintingERC20) USDC Proxy: 0x354D75465BD9e31c179b2423B20cbd0d1c82f274
- (LimitedMintingERC20) USDz Proxy: 0x5D75b1dbAA4cD2819cFD0259BD2021E186b914D9

  - Trading Account NFT: 0xF6b1cAed682335b251d6303C773CBaFA7a25f9A0
  - UpgradeBranch: 0x55Cd760aE18F1a6eA36837742bFA17a44722e796
  - LookupBranch: 0xe4d18045dF2504D3873bf48473C26D57AC07dD93
  - GlobalConfigurationBranch: 0x525De463774f39c6987F11E5dC9EA6F44D302419
  - LiquidationBranch: 0x93be2D485d8AC5f37Eb7DEA0616ad930e96d1E87
  - OrderBranch: 0xe0FdbB8b8bfBd43a35d7C4774Ba44AFE44C9A0A6
  - PerpMarketBranch: 0x9BD75B21a5552a78DBBC559147437607ca53A994
  - TradingAccountBranch: 0x7b73254eE30F0eDCed780cF49821b73ed418ef29
  - SettlementBranch: 0xE8c4C9663C20c8c2125A4C6aAeff9aac5D9D2FaB
  - Perps Engine Proxy: 0xB6B2eFe6A68a7E5B110F358Cd7719172e370BCA5
  - Liquidation Keeper: 0xe94C6379057591c353B43e4ca68b9B9c721f86BC
  - Access Key Manager Implementation: 0x91707cb94c53279c54E67B6750aF93C28D63e746
  - Access Key Manager Proxy: 0xEd8A959d7Be084A639b0a6a433FcFf21c2C1276B

  # Markets Configuration:
