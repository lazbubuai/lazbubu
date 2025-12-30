# Lazbubu

ERC1155 token contract with permit-based operations for adventures, memories, and personality management.

## Setup

```bash
npm install
```

## Test

```bash
npx hardhat test
```

## Deploy

```bash
npx hardhat deploy --signer <signer_address> --uri <token_uri>
```

## Contracts

- **Lazbubu**: Main ERC1155 token contract
- **PermitVerifier**: Handles permit verification and nonce management

## Features

- Mint tokens with permit signatures
- Create adventures and memories
- Set personality and level
- Claim message quota
- Transfer restrictions (only mature tokens can be transferred)

