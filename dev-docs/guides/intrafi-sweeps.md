# IntraFi and SVB Sweep account

Column is our main bank account, however, it has a low interest rate (APY). As a
result, we sweep 🧹 excess money to IntraFi to earn a higher interest rate.

Our IntraFi account is managed through SVB. Every day, SVB will push/pull money
between SVB FS Main and IntraFi such that SVB FS Main's balance is $250k.

## Bank Transactions (from SVB's perspective)

The memos of these transactions look like:

- `TF TO ICS SWP`: Transfer to IntraFi (withdrawal on SVB; deposit on IntraFi)
- `TF FRM ICS SWP`: Transfer from IntraFi (deposit on SVB; withdrawal on
  IntraFi)

## Bank Transactions (from IntraFi's perspective)

IntraFi's ICS (IntraFi Cash Sweep) dashboard, provides a 45-day transaction
history. Types of transactions include:

- `Deposit`: Money came in from SVB
- `Withdrawal`: Money went out to SVB
- `Interest Capitalization`: oooh, free money! 🤑

What's "Interest Capitalization" you ask? well, read on 📖

## Interest Accrual & Capitalization

IntraFi's interest rate fluctuates. As of time of writing (2025-01-14), our APY
is 3.35%; down from 3.55% in 2024-12-18. Interest is accrued based on our
**IntraFi Principal Balance**. This is amount of money that's currently in our
IntraFi account; which excludes any interest that's been accrued but not yet
paid out.

On the last day of each month, IntraFi pays out the accrued interest via an
**Interest Capitalization** transaction. This transaction takes our accrued
interest from that month and adds it to our **IntraFi Principal Balance**.

## Transaction Syncing to HCB

Usually, we sync all of Hack Club's active bank account into HCB. However,
IntraFi is the one exception. IntraFi unfortunately does play well with Plaid.
Therefore, we sync IntraFi's transactions into this HCB manually. IntraFi
provides a CSV export with the following headings: `Date`, `Account Activity`,
`Amount`, and `Balance`. Each row represents a transaction and should be
imported as a `RawIntrafiTransaction`:

```ruby
RawIntrafiTransaction.create(date_posted: tx[:Date], memo: tx[:"Account Activity"], amount_cents: tx[:Amount] * 100)
```

All IntraFi transactions should be mapped to the HCB Sweeps organization; *
*except** for Interest Capitalization transactions. These are auto-mapped to
**Hack Foundation Interest Earnings**.

After a batch of transactions has imported, HCB Sweep's balance should be
exactly zero since all deposits and withdrawals are paired (and cancel each
other out). In practice, a delay/time difference in syncing transactions between
banks could cause the balance to be non-zero. However _in theory_, it should be
zero.

\- [@garyhtou](https://garytou.com) & [@sampoder](https://sampoder.com)
