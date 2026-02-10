# How a transaction gets mapped to an event and a HCB code on HCB.
Or at least my attempt to describe this. Some transaction types have been deprecated and are not described in this guide, though the code may still exist in the codebase.
### Column Transactions

Column transactions start off as being imported from a daily Column report (https://column.com/docs/guides/reporting). This code is in [`TransactionEngine::Nightly`](https://github.com/hackclub/hcb/blob/main/app/services/transaction_engine/nightly.rb). Each line item in that report has an associated [`RawColumnTransaction`](https://github.com/hackclub/hcb/blob/main/app/models/raw_column_transaction.rb).

After a [`RawColumnTransaction`](https://github.com/hackclub/hcb/blob/main/app/models/raw_column_transaction.rb) is created, an `after_create` callback creates a [`CanonicalTransaction`](https://github.com/hackclub/hcb/blob/main/app/models/canonical_transaction.rb) for this transaction. Here’s where our paths diverge for different transaction types. 

Each type of transfer has a different HCB code. HCB “calculates” the correct HCB code for a transfer in [`TransactionGroupingEngine::Calculate::HcbCode`](https://github.com/hackclub/hcb/blob/main/app/services/transaction_grouping_engine/calculate/hcb_code.rb) and then writes that HCB code to the [`CanonicalTransaction`](https://github.com/hackclub/hcb/blob/main/app/models/canonical_transaction.rb)s `hcb_code` column inside of `CanonicalTransaction#write_hcb_code`.

If this is an account number transaction of some other “unknown” transfer type that has came from Column, it will be give a HCB code starting with “HCB-000”. There won’t be a linked object in these cases.

[`TransactionGroupingEngine::Calculate::HcbCode`](https://github.com/hackclub/hcb/blob/main/app/services/transaction_grouping_engine/calculate/hcb_code.rb) depends on `CanonicalTransaction#linked_object`, which is determined in [`TransactionEngine::SyntaxSugarService::LinkedObject`](https://github.com/hackclub/hcb/blob/main/app/services/transaction_engine/syntax_sugar_service/linked_object.rb).

The final step in this process is for the transaction to be mapped to an event. This can either be through the Column account numbers or through some transfer type-specific logic. 

Transfers, both inbound and outbound, can be received / sent to the account numbers specific to an organisation. Transfers with this will be mapped by `EventMappingEngine::Nightly#map_column_account_number_transactions!`. 

The transfer type-specific logic can also be found in [`EventMappingEngine::Nightly`](https://github.com/hackclub/hcb/blob/main/app/services/event_mapping_engine/nightly.rb); for example, `EventMappingEngine::Nightly#map_achs!`.

If a transfer can’t be mapped through any of these methods, it’ll appear on https://hcb.hackclub.com/admin/ledger and an admin on HCB can then manually map it. This manual mapping is done through [`CanonicalTransactionService::SetEvent`](https://github.com/hackclub/hcb/blob/main/app/services/canonical_transaction_service/set_event.rb).

### Disbursements

Disbursements are Column book transfers (https://column.com/docs/book-transfers-and-holds) between “FS Main” and “FS Operating”. There are two book transfers for every disbursement:

FS Main -> FS Operating: this will be a negative transaction on FS Main (the only Column account we import from) and should be mapped to the organisation that sent the disbursement.

FS Operating -> FS Main: this will be a positive transaction on FS Main and should be mapped to the organisation that is receiving the disbursement.

HCB operates under the assumption that FS Operating has a balance of $0. Any money that goes in must come out.

Each of these book transfers has a memo in this format: `HCB DISBURSE [ID]`.


> [!WARNING]
> This section is outdated. HCB short code mapping is now used for Disbursements.

Based on the ID, `EventMappingEngine::Map::Disbursements` will map the transactions to their associated event and subledger. The logic for determining whether it should be mapped to the receiving event or the source event is based on `amount_cents` and is located in `EventMappingEngine::GuessEventId::Disbursement`. If it’s a positive transaction, we map it to the receiving event. If it’s a negative transaction, we map it to the source event.

[`TransactionGroupingEngine::Calculate::HcbCode`](https://github.com/hackclub/hcb/blob/main/app/services/transaction_grouping_engine/calculate/hcb_code.rb) handles calculating the HCB code, as described above.

### Card Top-ups & Stripe Top-ups

Every time we issue a card, we need to pay Stripe for printing / shipping etc. They automatically subtract this from our balance. We top-up our balance from our bank account.

Each of these top-up transactions are mapped to the Bank organisation on HCB: hcb.hackclub.com/bank. This is done based on the [`CanonicalTransaction`](https://github.com/hackclub/hcb/blob/main/app/models/canonical_transaction.rb)s memo meeting the following criteria:

```sql
memo ilike 'Hack Club Bank Issued car%' or memo ilike 'HCKCLB Issued car%' or memo ilike 'STRIPE Issued car%'
``` 

We map all of our Stripe top-ups to hcb.hackclub.com/noevent. They are also identified based on [`CanonicalTransaction`](https://github.com/hackclub/hcb/blob/main/app/models/canonical_transaction.rb)s memo:

```sql
memo ilike '%Hack Club Bank Stripe Top%' or memo ilike '%HACKC Stripe Top%' or memo ilike '%HCKCLB Stripe Top%' or memo ilike '%STRIPE Stripe Top%'
```

### Outgoing Stripe Fee Reimbursements

Incoming fee reimbursements (refunding people for the credit card fees Stripe deducts etc.) are mapped by the short codes system described below. These are book transfers so they need an outgoing transaction as well. These outgoing transactions all have are all mapped to hcb.hackclub.com/bank using HCB short codes.

### HCB Short Codes (Reimbursements, Invoices, Fees, Stripe Fee Reimbursements and Donations)

HCB short codes are a bit like dark magic. Essentially, if a [`CanonicalTransaction`](https://github.com/hackclub/hcb/blob/main/app/models/canonical_transaction.rb)s `memo` contains a “short code” (`/HCB-\w{5}/`, eg `HCB-ABCDE`), we can use that to uniquely map it to a HCB code. Critically, this is different from a HCB code’s hash ID which you see in URLs. A HCB code’s short code is generated before create in `HcbCode#generate_and_set_short_code`.

The logic for this mapping is in [`EventMappingEngine::Map::HcbCodes::Short`](https://github.com/hackclub/hcb/blob/main/app/services/event_mapping_engine/map/hcb_codes/short.rb). It handles setting the [`CanonicalTransaction`](https://github.com/hackclub/hcb/blob/main/app/models/canonical_transaction.rb)s `hcb_code` and mapping it to an event (as well as a subledger, if needed). The event and subledger are determined by the HCB code’s pre-linked [`CanonicalTransaction`](https://github.com/hackclub/hcb/blob/main/app/models/canonical_transaction.rb)s and/or [`CanonicalPendingTransaction`](https://github.com/hackclub/hcb/blob/main/app/models/canonical_pending_transaction.rb)s.

#### Invoices and Donations

That’s how invoices and donations can be imported once they leave Stripe. But how do we tell them to leave Stripe? To do this, we create Stripe payouts from our balance when an invoice or donation is paid. This logic can be found in [`InvoicePayout`](https://github.com/hackclub/hcb/blob/main/app/models/invoice_payout.rb) and [`DonationPayout`](https://github.com/hackclub/hcb/blob/main/app/models/donation_payout.rb).

#### Reimbursements

We use a clearinghouse organisation for reimbursements. This means that the ACHs, checks, etc. we send to reimburse people are standard ACHs / checks, just like the ones any organisation would send! See [`Reimbursement::PayoutHoldingService::Nightly`](https://github.com/hackclub/hcb/blob/main/app/services/reimbursement/payout_holding_service/nightly.rb) for how this is done.

The transactions that are imported by HCB short code are the [`Reimbursement::ExpensePayout`](https://github.com/hackclub/hcb/blob/main/app/models/reimbursement/expense_payout.rb) and the [`Reimbursement::PayoutHolding`](https://github.com/hackclub/hcb/blob/main/app/models/reimbursement/payout_holding.rb). These are internal book transfers that move money from the organisation that is reimbursing someone to the clearinghouse organisation.

An [`Reimbursement::ExpensePayout`](https://github.com/hackclub/hcb/blob/main/app/models/reimbursement/expense_payout.rb) is a book transfer from “FS Main” to “FS Operating”. It comes in as a negative [`CanonicalTransaction`](https://github.com/hackclub/hcb/blob/main/app/models/canonical_transaction.rb). A [`Reimbursement::Report`](https://github.com/hackclub/hcb/blob/main/app/models/reimbursement/report.rb) can have multiple of these [`Reimbursement::ExpensePayout`](https://github.com/hackclub/hcb/blob/main/app/models/reimbursement/expense_payout.rb)s, one for every [`Reimbursement::Expense`](https://github.com/hackclub/hcb/blob/main/app/models/reimbursement/expense.rb) that was approved. 

A [`Reimbursement::PayoutHolding`](https://github.com/hackclub/hcb/blob/main/app/models/reimbursement/payout_holding.rb) is a book transfer from “FS Operating” to “FS Main”. It comes in as a positive [`CanonicalTransaction`](https://github.com/hackclub/hcb/blob/main/app/models/canonical_transaction.rb). A [`Reimbursement::Report`](https://github.com/hackclub/hcb/blob/main/app/models/reimbursement/report.rb) can only have one [`Reimbursement::PayoutHolding`](https://github.com/hackclub/hcb/blob/main/app/models/reimbursement/payout_holding.rb). Its `amount_cents` will be the sum of the [`Reimbursement::Report`](https://github.com/hackclub/hcb/blob/main/app/models/reimbursement/report.rb)s [`Reimbursement::ExpensePayout`](https://github.com/hackclub/hcb/blob/main/app/models/reimbursement/expense_payout.rb)s' `amount_cents`.

### Subledgers

Events can have subledgers. For example, a card grant. When mapping these transactions to an event, we map them to the event as usual but add an additional `subledger_id` to the [`CanonicalEventMapping`](https://github.com/hackclub/hcb/blob/main/app/models/canonical_event_mapping.rb). Not all transaction importing mechanisms support this at the moment. However, they are supported by HCB short code mapping (“guessed” based on the HCB code’s other transactions), disbursements (based on the [`Disbursement`](https://github.com/hackclub/hcb/blob/main/app/models/disbursement.rb)s `source_subledger_id` and `destination_subledger_id`), and Stripe card transactions (based on the [`StripeCard`](https://github.com/hackclub/hcb/blob/main/app/models/stripe_card.rb)s `subledger_id`).

### Stripe Card Transactions

This begins in [`TransactionEngine::Nightly`](https://github.com/hackclub/hcb/blob/main/app/services/transaction_engine/nightly.rb) by importing a list of transactions from Stripe: [`Partners::Stripe::Issuing::Transactions::List`](https://github.com/hackclub/hcb/blob/main/app/services/partners/stripe/issuing/transactions/list.rb) (view https://docs.stripe.com/api/issuing/transactions/list). For each transaction returned by Stripe, we create a [`RawStripeTransaction`](https://github.com/hackclub/hcb/blob/main/app/models/raw_stripe_transaction.rb) if it doesn’t already exist. 

Afterwards, [`TransactionEngine::Nightly`](https://github.com/hackclub/hcb/blob/main/app/services/transaction_engine/nightly.rb) continues by calling [`TransactionEngine::HashedTransactionService::RawStripeTransaction::Import`](https://github.com/hackclub/hcb/blob/main/app/services/transaction_engine/hashed_transaction_service/raw_stripe_transaction/import.rb), which loops through each of these [`RawStripeTransaction`](https://github.com/hackclub/hcb/blob/main/app/models/raw_stripe_transaction.rb)s to create a “hashed transaction”.

Still inside of [`TransactionEngine::Nightly`](https://github.com/hackclub/hcb/blob/main/app/services/transaction_engine/nightly.rb), after these transactions are hashed, they are “canonized” by [`TransactionEngine::CanonicalTransactionService::Import::All`](https://github.com/hackclub/hcb/blob/main/app/services/transaction_engine/canonical_transaction_service/import/all.rb). That is to say that a [`CanonicalTransaction`](https://github.com/hackclub/hcb/blob/main/app/models/canonical_transaction.rb) was created.

This [`CanonicalTransaction`](https://github.com/hackclub/hcb/blob/main/app/models/canonical_transaction.rb) is mapped to a HCB code using the aforementioned `CanonicalTransaction#write_hcb_code`. See above for a description of that method.

[`EventMappingEngine::Map::StripeTransactions`](https://github.com/hackclub/hcb/blob/main/app/services/event_mapping_engine/map/stripe_transactions.rb) then calls [`EventMappingEngine::Map::Single::Stripe`](https://github.com/hackclub/hcb/blob/main/app/services/event_mapping_engine/map/single/stripe.rb) on each of these unmapped (no event) Stripe transactions. The event ID is determined by the [`StripeCard`](https://github.com/hackclub/hcb/blob/main/app/models/stripe_card.rb)s event. The [`StripeCard`](https://github.com/hackclub/hcb/blob/main/app/models/stripe_card.rb) is determined by Stripe card ID (`stripe_transaction["card"]`, the `stripe_id` field on [`StripeCard`](https://github.com/hackclub/hcb/blob/main/app/models/stripe_card.rb))

### Plaid Transactions

We have a set of “connected” bank accounts on HCB: https://hcb.hackclub.com/admin/bank_accounts. If you’ve heard about the [infamous SVB account](https://vtdigger.org/2023/03/17/vermont-based-hack-club-managed-to-move-its-money-out-of-silicon-valley-bank-before-it-closed/), this is how it connects!

Most banks aren’t like Column and they don’t have a well documented API, instead we use a service called Plaid: https://plaid.com/solutions/open-finance/. Plaid is a wrapper that provides you with one API for getting transactions from all sorts of banks. Frankly, it’s a bit of a black box.

We fetch these transactions through Plaid inside of [`TransactionEngine::RawPlaidTransactionService::Plaid::Import`](https://github.com/hackclub/hcb/blob/main/app/services/transaction_engine/raw_plaid_transaction_service/plaid/import.rb). We use this API from Plaid: https://plaid.com/docs/api/products/transactions/#transactionsget. In here a [`RawPlaidTransaction`](https://github.com/hackclub/hcb/blob/main/app/models/raw_plaid_transaction.rb) is created.

A [`RawPlaidTransaction`](https://github.com/hackclub/hcb/blob/main/app/models/raw_plaid_transaction.rb)s journey is a lot like a [`RawStripeTransaction`](https://github.com/hackclub/hcb/blob/main/app/models/raw_stripe_transaction.rb)s journey. In [`TransactionEngine::Nightly`](https://github.com/hackclub/hcb/blob/main/app/services/transaction_engine/nightly.rb), it is hashed by [`TransactionEngine::HashedTransactionService::RawPlaidTransaction::Import`](https://github.com/hackclub/hcb/blob/main/app/services/transaction_engine/hashed_transaction_service/raw_plaid_transaction/import.rb).

It is then “canonized” by [`TransactionEngine::CanonicalTransactionService::Import::All`](https://github.com/hackclub/hcb/blob/main/app/services/transaction_engine/canonical_transaction_service/import/all.rb). 

Most [`CanonicalTransaction`](https://github.com/hackclub/hcb/blob/main/app/models/canonical_transaction.rb)s then show up on https://hcb.hackclub.com/admin/ledger to be mapped manually. Though it might be automatically mapped by short code.

### PayPal Transfers

> [!WARNING]
> PayPal transfers have been deprecated and are no longer a standard way of making transfers on HCB.

PayPal transfers are a unique type of transfer. It may look like HCB automatically sends PayPal transfers but it doesn’t. Instead an operations staff member manually logs into PayPal and sends it using funds from our Column account (linked as a bank account on PayPal). This means they come through as a [`RawColumnTransaction`](https://github.com/hackclub/hcb/blob/main/app/models/raw_column_transaction.rb). Refer to the above section on Column transfers for the flow from [`RawColumnTransaction`](https://github.com/hackclub/hcb/blob/main/app/models/raw_column_transaction.rb) -> [`CanonicalTransaction`](https://github.com/hackclub/hcb/blob/main/app/models/canonical_transaction.rb). However, there is no code to automatically map these PayPal transfers so these transactions land on https://hcb.hackclub.com/admin/ledger. 

An admin then fills in this form:

<img src="https://cdn.hackclub.com/rescue?url=https://hc-cdn.hel1.your-objectstorage.com/s/v3/5fced0ca3ada544b_image.png" width="291px" />

A request is made to `AdminController#set_paypal_transfer` which uses [`CanonicalTransactionService::SetEvent`](https://github.com/hackclub/hcb/blob/main/app/services/canonical_transaction_service/set_event.rb), `CanonicalPendingTransactionService::Settle.new` to map it to an event and settle it’s associated pending transaction. Lastly, there’s this line:

```ruby
canonical_transaction.update!(hcb_code: paypal_transfer.hcb_code, transaction_source_type: "PaypalTransfer", transaction_source_id: paypal_transfer.id)
```

### Settled Mappings

We have [`CanonicalPendingTransaction`](https://github.com/hackclub/hcb/blob/main/app/models/canonical_pending_transaction.rb)s on HCB. I haven’t dived into these as much in this guide as they come before this stage. Essentially, they’re created when we expect a certain transaction to happen but it hasn’t shown up on our bank statement yet. When that transaction does show up on our bank statement, we want to map this [`CanonicalTransaction`](https://github.com/hackclub/hcb/blob/main/app/models/canonical_transaction.rb) to a [`CanonicalPendingTransaction`](https://github.com/hackclub/hcb/blob/main/app/models/canonical_pending_transaction.rb). This takes place in [`PendingEventMappingEngine::Nightly`](https://github.com/hackclub/hcb/blob/main/app/services/pending_event_mapping_engine/nightly.rb). 

`PendingEventMappingEngine::Nightly#settle_canonical_pending_wire!` is an example of this.

### Examples

Below are a couple of PRs, that were made to transition wires from being manual (like PayPal transfers) to being sent through Column.

* Creating a `send_wire` method: https://github.com/hackclub/hcb/pull/8336 and https://github.com/hackclub/hcb/pull/8366
* Adding Column wires to [`SyntaxSugarService`](https://github.com/hackclub/hcb/blob/main/app/services/transaction_engine/syntax_sugar_service): https://github.com/hackclub/hcb/pull/8416 and https://github.com/hackclub/hcb/pull/8417
* Create `settle_canonical_pending_wire!`: https://github.com/hackclub/hcb/pull/8419 

Event mapping was handled by the Column account numbers.

I would also recommend referencing this PR that created the [`PaypalTransfer`](https://github.com/hackclub/hcb/blob/main/app/models/paypal_transfer.rb) system: https://github.com/hackclub/hcb/pull/6261 (eek! it’s large).

*This guide is new and I’m still working on it! ping me ([@sampoder](https://github.com/sampoder)) if there’s a transaction type missing, something is wrong or confusing etc. But thank you for reading to the end!*

\- [@sampoder](https://github.com/sampoder)
