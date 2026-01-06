# Lazbubu

Lazbubu Companion [DATs (Data Anchoring Tokens)](https://docs.lazai.network/lazainetwork/user-docs/welcome-to-lazai/lazai-solution/dat-data-anchoring-token) are AI agents with memory, personality, and evolving abilities, designed for long-term interaction and value creation.

The smart contract implements ERC1155 with EIP712 permit-based authorization for adventures, memories, and personality management. 

Deployed on BNB Smart Chain: [0xd03253915594ab2af3458d85d6668aea01195970](https://bscscan.com/address/0xd03253915594ab2af3458d85d6668aea01195970)

## Setup

```bash
npm install
```

## Test

```bash
npx hardhat test
```

## Deployment

```bash
npx hardhat deploy --signer <signer_address> --uri <token_uri>
```

## Contracts

- **Lazbubu**: Main ERC1155 token contract with integrated permit verification

## Features

- EIP712 permit-based token minting
- Adventure and memory creation
- Personality and level management
- Message quota claiming
- Transfer restrictions (mature tokens only)

