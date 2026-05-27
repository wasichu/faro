Implement the FTC wallet and ledger system.

Goals:
- persistent fake-token balances
- append-only ledger entries
- transactional bet/settlement integration

Requirements:
- create Wallet and LedgerEntry Ash resources
- use integer sats for FTC amounts
- create default FTC wallet/balance for anonymous sessions
- all balance changes must happen through LedgerEntry
- prevent betting more than available balance
- record debits for bets
- record credits for payouts
- support withdrawal-like holds later, but do not implement withdrawals now
- add tests for balance correctness, insufficient funds, and transaction rollback

Do not add BTC, Oban, deposits, withdrawals, or auth changes.
