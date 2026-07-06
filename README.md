# ChainSplit

Decentralized expense-splitting dApp on Avalanche — inspired by Splitwise, with on-chain expenses, balance tracking, and AVAX settlements.

## Tech Stack

- **Smart contracts:** Solidity, Hardhat, OpenZeppelin
- **Frontend:** React, Vite, TypeScript, Tailwind (Phase 2)
- **Network:** Avalanche Fuji Testnet

## Project Structure

```
contracts/          ExpenseSplit.sol
scripts/            deploy.ts
test/               ExpenseSplit.test.ts
hardhat.config.ts
```

## Getting Started

```bash
npm install
cp .env.example .env   # add PRIVATE_KEY for Fuji deployment
npm run compile
npm test
npm run deploy:fuji
```

## Smart Contract

`ExpenseSplit` supports:

- Group creation with member wallets
- Expenses with equal, percentage, or custom splits
- Automatic debt/balance calculation with netting
- AVAX debt settlement
- QR settlement requests with reference IDs

## Development Phases

1. **Phase 1** — Smart contracts (current)
2. **Phase 2** — React frontend + wallet integration
3. **Phase 3** — UI polish, AI receipt scanner, analytics
4. **Phase 4** — Testing, deployment, documentation

## License

MIT
