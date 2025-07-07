# MiniLendingProtocol

```
███╗   ███╗██╗███╗   ██╗██╗███╗   ██╗██╗     ███████╗███╗   ██╗██████╗ 
████╗ ████║██║████╗  ██║██║████╗  ██║██║     ██╔════╝████╗  ██║██╔══██╗
██╔████╔██║██║██╔██╗ ██║██║██╔██╗ ██║██║     █████╗  ██╔██╗ ██║██║  ██║
██║╚██╔╝██║██║██║╚██╗██║██║██║╚██╗██║██║     ██╔══╝  ██║╚██╗██║██║  ██║
██║ ╚═╝ ██║██║██║ ╚████║██║██║ ╚████║███████╗███████╗██║ ╚████║██████╔╝
╚═╝     ╚═╝╚═╝╚═╝  ╚═══╝╚═╝╚═╝  ╚═══╝╚══════╝╚══════╝╚═╝  ╚═══╝╚═════╝ 
```

Minimal ERC20-based lending protocol built in Solidity with dynamic interest accrual, collateralized borrowing, and liquidation. Built with Foundry. Designed for practical protocol architecture demonstration.

---

## Overview

```
┌───────────────────────────────────────────────────────┐
│                     LendingPool                       │
│  ───────────────────────────────────────────────────  │
│  supply(token, amount)                                │
│  withdraw(token, amount)                              │
│  borrow(token, amount)                                │
│  repay(token, amount)                                 │
│  liquidate(token, user, repayAmount)                  │
│  utilization(token)                                   │
│  getBorrowRate(token)                                 │
└───────────────────────────────────────────────────────┘
┌───────────────────────────────────────────────────────┐
│                      Storage                          │
│ collateral[user][token]                               │
│ borrowed[user][token]                                 │
│ lastUpdate[user][token]                               │
│ totalSupplied[token]                                  │
│ totalBorrowed[token]                                  │
└───────────────────────────────────────────────────────┘
```

---

## Core Mechanics

### Collateral & Borrowing
- Users supply ERC20 tokens
- Can borrow up to **50%** of supplied value (LTV)
- Only same-token borrow (isolated markets)

### Interest Model (Compound-style)
- Dynamic interest rate based on utilization:
```
rate = baseRate + slope * utilization
utilization = borrowed / supplied
```
- Base Rate: 5%  
- Slope: 20%

### Liquidation
- Triggered when debt > 50% of collateral
- Liquidators repay borrower's debt
- 110% of repayment is seized from borrower's collateral

---

## Usage

```bash
git clone https://github.com/Alpy16/MiniLendingProtocol.git
cd MiniLendingProtocol
forge install
forge build
forge test -vv
```

To deploy locally with Anvil:
```bash
anvil
# In another terminal
forge script script/Deploy.s.sol --broadcast --rpc-url http://127.0.0.1:8545
```

---

## Test Coverage

Run all tests with verbose output:
```bash
forge test -vv
```

Test Cases:
- Supply / Withdraw
- Borrow / Repay
- Interest Accrual over time
- Liquidation behavior
- Token isolation
- Utilization calculation

---

## Design Notes

- Single LendingPool for all tokens
- Interest only accrues on action (lazy update)
- No oracles (assumes token:token 1:1)
- No admin role / governance
- Fully testable & modular

---

## Limitations

This project is **not production-ready**. It lacks:
- Price oracles
- Flash loan protection
- Reentrancy guards
- Cross-token collateral
- Health factor / safe margin logic
- Risk engine or governance

Used only for learning and getting experience so i simply did not need to implement most of this stuff

---

## License

MIT

---

Made by [Alpy16](https://github.com/Alpy16)
# MiniLendingProtocol
