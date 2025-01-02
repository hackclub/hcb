# How does the flow of money work for reimbursements on HCB?

Reimbursements are one of the more complicated parts of HCB! This isn’t a comprehensive guide to how they work, instead, this describes how money flows through the system. 

To send the person being reimbursed money, we use standard HCB transfers such as an `AchTransfer` and a `PaypalTransfer`. However, we send these transfers from the “HCB Reimbursements Clearinghouse” organisation. On the organisation that is sending the reimbursement we have one transaction on the ledger per reimbursed expense (these are called `ExpensePayout`s). We took this approach to increase transparency and make it to understand what a reimbursement is for.

A `Reimbursement::Report` is a collection of `Reimbursement::Expenses`. No money moves until a report is approved by an admin and, if needed, an organiser. 

When a `Reimbursement::Report` is marked as `reimbursement_approved` by an admin, we run `Reimbursement::Report#reimburse!` which creates one `ExpensePayout` per approved expense and one `PayoutHolding` for the report.

These transactions internal book transfers that move money from the organisation that is reimbursing someone to the clearinghouse organisation.

An `ExpensePayout` is a book transfer from “FS Main” to “FS Operating”. It comes in as a negative `CanonicalTransaction`.

An `PayoutHolding` is a book transfer from “FS Operating” to “FS Main”. It comes in as a positive `CanonicalTransaction`. A `Reimbursement::Report` can only have one `PayoutHolding`. It’s `amount_cents` will be the sum of the `Reimbursement::Report`’s `ExpensePayout`s’ `amount_cents`.

They are both created in `Reimbursement::Report#reimburse!` 

After they are both created, they have `after_create` callbacks that create a `CanonicalPendingTransaction`. That means there will immediately be a transaction on the ledgers of both the reimbursing organisation and HCB Reimbursements Clearinghouse.

`Reimbursement::ExpensePayoutService::Nightly` is ran every five minutes and creates Column book transfers for each of these. 

It also marks any `ExpensePayout` with a `CanonicalTransaction` as settled.

And a `PayoutHolding` with either a `CanonicalTransaction` or a `CanonicalPendingTransaction` as settled. You’ll notice that every `PayoutHolding` should meet this condition. This is true. It used to wait for a `CanonicalTransaction` but we started fronting the `CanonicalPendingTransaction` so it would immediately increase HCB Reimbursement Clearinghouse’s balance. That’s because these transactions are guaranteed to end up on our bank statement. 

`Reimbursement::PayoutHoldingService::Nightly` goes through each settled `PayoutHolding` and sends the money to the user based on their `User::PayoutMethod` which is a polymorphic relationship on the `User` model.

And for 99% of reports, that’s the end of it!

But for that 1%…

### Failed `PayoutHolding`s

If we attempt to send an `AchTransfer` or a `PaypalTransfer` and it fails (for ACHs, this means it errors and for PayPal transfers, this means a human tried to send it but something didn’t work), we mark the `PayoutHolding` as `failed`.

Users receive an email asking them to update their payout information. In the meantime, the `PayoutHolding` just sits in a holding state with the money staying in the HCB Reimbursements Clearinghouse.

Once a user updates their payout information, we mark all of their failed `PayoutHolding`s as `settled` and try the process all over again.

### Reversed `PayoutHolding`s

In a very rare set of circumstances, we “reverse” a `PayoutHolding`. That means that the money leaves the HCB Reimbursements Clearinghouse organisation and goes back to the organisation which the report was on. This has to be manually triggered by an engineer by calling `PayoutHolding#reverse!` in the production console.

We perform the following sanity checks:

```ruby
raise ArgumentError, "must be a reimbursed report" unless report.reimbursed?

raise ArgumentError, "must be a failed payout holding" unless failed?

raise ArgumentError, "ACH must have been rejected / failed" unless ach_transfer.nil? || ach_transfer.failed? || ach_transfer.rejected?

raise ArgumentError, "PayPal transfer must have been rejected" unless paypal_transfer.nil? || paypal_transfer.rejected?

raise ArgumentError, "a check is present" if increase_check.present?
```

And if it passes, we create a set of Column book transfers that are essentially the reverse of what we created above. 

After this the report will never be reimbursed.

\- [@sampoder](https://github.com/sampoder)
