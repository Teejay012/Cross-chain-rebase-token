# Cross-Chain Token Bridge

A Solidity-based system for **bridging rebasing ERC20 tokens** between Sepolia Ethereum and Arbitrum Sepolia testnets, using Foundry for testing.

## ✨ Features

- 🚀 **Cross-chain token transfer simulation**  
  Move rebasing tokens seamlessly between two chains.
  
- 🔄 **Rebasing support**  
  Tokens that automatically adjust supply while maintaining user balances.
  
- 🛡 **Secure bridging with interest rate tracking**  
  Keeps user balance and interest rates consistent across chains.

- 🧪 **Full Foundry test suite**  
  Fork-based tests simulating Sepolia Ethereum and Arbitrum Sepolia environments.

---

## 🏗 Contracts

| Contract              | Description                                      |
|-----------------------|--------------------------------------------------|
| `RebaseToken`         | ERC20-compatible rebasing token contract         |
| `Bridge`              | Handles cross-chain message passing and minting  |
| `MockArbitrumBridge`  | Simulates Arbitrum bridging in local tests       |

---

## 🛠 Setup

### Prerequisites

- [Foundry](https://book.getfoundry.sh/) installed  
  → Install with:  
  ```bash
  curl -L https://foundry.paradigm.xyz | bash
  foundryup

### Install Dependencies

```shell
forge install
```

### Deploy Contracts

```shell
forge script script/Deployer.s.sol:(enter what you want to deploy) --rpc-url ${source / remote rpc url} account (use your keystore account) --broadcast
```

## ✍️ Author
TJ (@EtherEngineer)
Twitter: [@EtherEngineer](https://x.com/Tee_Jay4life)
Building DeFi from scratch. One smart contract at a time.



## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
