# How does the flow of money work for reimbursements on HCB?

Reimbursements are one of the more complicated parts of HCB! This isn’t a comprehensive guide to how they work, instead, this describes how money flows through the system. 

To send the person being reimbursed money, we use standard HCB transfers such as an [`AchTransfer`](https://github.com/hackclub/hcb/blob/main/app/models/ach_transfer.rb). However, we send these transfers from the “HCB Reimbursements Clearinghouse” organisation. On the organisation that is sending the reimbursement we have one transaction on the ledger per reimbursed expense (these are called [`Reimbursement::ExpensePayout`](https://github.com/hackclub/hcb/blob/main/app/models/reimbursement/expense_payout.rb)s). We took this approach to increase transparency and make it easier to understand what a reimbursement is for.

A [`Reimbursement::Report`](https://github.com/hackclub/hcb/blob/main/app/models/reimbursement/report.rb) is a collection of [`Reimbursement::Expense`](https://github.com/hackclub/hcb/blob/main/app/models/reimbursement/expense.rb)s. No money moves until a report is approved by an admin and if needed, an organiser. 

When a [`Reimbursement::Report`](https://github.com/hackclub/hcb/blob/main/app/models/reimbursement/report.rb) is marked as `reimbursement_approved` by an admin, we run `Reimbursement::Report#reimburse!` which creates one [`Reimbursement::ExpensePayout`](https://github.com/hackclub/hcb/blob/main/app/models/reimbursement/expense_payout.rb) per approved expense and one [`Reimbursement::PayoutHolding`](https://github.com/hackclub/hcb/blob/main/app/models/reimbursement/payout_holding.rb) for the report.

These transactions are internal book transfers that move money from the organisation that is reimbursing someone to the clearinghouse organisation.

A [`Reimbursement::ExpensePayout`](https://github.com/hackclub/hcb/blob/main/app/models/reimbursement/expense_payout.rb) is a book transfer from “FS Main” to “FS Operating”. It comes in as a negative [`CanonicalTransaction`](https://github.com/hackclub/hcb/blob/main/app/models/canonical_transaction.rb).

A [`Reimbursement::PayoutHolding`](https://github.com/hackclub/hcb/blob/main/app/models/reimbursement/payout_holding.rb) is a book transfer from “FS Operating” to “FS Main”. It comes in as a positive [`CanonicalTransaction`](https://github.com/hackclub/hcb/blob/main/app/models/canonical_transaction.rb). A [`Reimbursement::Report`](https://github.com/hackclub/hcb/blob/main/app/models/reimbursement/report.rb) can only have one [`Reimbursement::PayoutHolding`](https://github.com/hackclub/hcb/blob/main/app/models/reimbursement/payout_holding.rb). Its `amount_cents` will be the sum of the [`Reimbursement::Report`](https://github.com/hackclub/hcb/blob/main/app/models/reimbursement/report.rb)’s [`Reimbursement::ExpensePayout`](https://github.com/hackclub/hcb/blob/main/app/models/reimbursement/expense_payout.rb)s’ `amount_cents`.

These are both created in `Reimbursement::Report#reimburse!` 

After they are both created, they have `after_create` callbacks that create a [`CanonicalPendingTransaction`](https://github.com/hackclub/hcb/blob/main/app/models/canonical_pending_transaction.rb). That means there will immediately be a transaction on the ledgers of both the reimbursing organisation and HCB Reimbursements Clearinghouse.

[`Reimbursement::ExpensePayoutService::Nightly`](https://github.com/hackclub/hcb/blob/main/app/services/reimbursement/expense_payout_service/nightly.rb) is ran every five minutes and creates Column book transfers for each of these. 

It also marks any [`Reimbursement::ExpensePayout`](https://github.com/hackclub/hcb/blob/main/app/models/reimbursement/expense_payout.rb) with a [`CanonicalTransaction`](https://github.com/hackclub/hcb/blob/main/app/models/canonical_transaction.rb) as settled.

And a [`Reimbursement::PayoutHolding`](https://github.com/hackclub/hcb/blob/main/app/models/reimbursement/payout_holding.rb) with either a [`CanonicalTransaction`](https://github.com/hackclub/hcb/blob/main/app/models/canonical_transaction.rb) or a [`CanonicalPendingTransaction`](https://github.com/hackclub/hcb/blob/main/app/models/canonical_pending_transaction.rb) as settled. You’ll notice that every [`Reimbursement::PayoutHolding`](https://github.com/hackclub/hcb/blob/main/app/models/reimbursement/payout_holding.rb) should meet this condition. This is true. It used to wait for a [`CanonicalTransaction`](https://github.com/hackclub/hcb/blob/main/app/models/canonical_transaction.rb) but we started fronting the [`CanonicalPendingTransaction`](https://github.com/hackclub/hcb/blob/main/app/models/canonical_pending_transaction.rb) so it would immediately increase HCB Reimbursement Clearinghouse’s balance. That’s because these transactions are guaranteed to end up on our bank statement. 

[`Reimbursement::PayoutHoldingService::Nightly`](https://github.com/hackclub/hcb/blob/main/app/services/reimbursement/payout_holding_service/nightly.rb) goes through each settled [`Reimbursement::PayoutHolding`](https://github.com/hackclub/hcb/blob/main/app/models/reimbursement/payout_holding.rb) and sends the money to the user based on their [`User::PayoutMethod`](https://github.com/hackclub/hcb/blob/main/app/models/user/payout_method.rb) which is a polymorphic relationship on the [`User`](https://github.com/hackclub/hcb/blob/main/app/models/user.rb) model.

And for 99% of reports, that’s the end of it!

But for that 1%…

### Failed [`Reimbursement::PayoutHolding`](https://github.com/hackclub/hcb/blob/main/app/models/reimbursement/payout_holding.rb)s

If we attempt to send an [`AchTransfer`](https://github.com/hackclub/hcb/blob/main/app/models/ach_transfer.rb) and Column errors or it is returned, we mark the [`Reimbursement::PayoutHolding`](https://github.com/hackclub/hcb/blob/main/app/models/reimbursement/payout_holding.rb) as `failed`.

Users receive an email asking them to update their payout information. In the meantime, the [`Reimbursement::PayoutHolding`](https://github.com/hackclub/hcb/blob/main/app/models/reimbursement/payout_holding.rb) just sits in a holding state with the money staying in the HCB Reimbursements Clearinghouse.

Once a user updates their payout information, we mark all of their failed [`Reimbursement::PayoutHolding`](https://github.com/hackclub/hcb/blob/main/app/models/reimbursement/payout_holding.rb)s as `settled` and try the process all over again.

### Reversed [`Reimbursement::PayoutHolding`](https://github.com/hackclub/hcb/blob/main/app/models/reimbursement/payout_holding.rb)s

In a very rare set of circumstances, we “reverse” a [`Reimbursement::PayoutHolding`](https://github.com/hackclub/hcb/blob/main/app/models/reimbursement/payout_holding.rb). That means that the money leaves the HCB Reimbursements Clearinghouse organisation and goes back to the organisation which the report was on. This has to be manually triggered by an engineer by calling `Reimbursement::PayoutHolding#reverse!` in the production console.

We perform the following sanity checks:

```ruby
raise ArgumentError, "must be a reimbursed report" unless report.reimbursed?

raise ArgumentError, "must be a failed payout holding" unless failed?

raise ArgumentError, "ACH must have been rejected / failed" unless ach_transfer.nil? || ach_transfer.failed? || ach_transfer.rejected?

raise ArgumentError, "PayPal transfer must have been rejected" unless paypal_transfer.nil? || paypal_transfer.rejected?

raise ArgumentError, "a check is present" if increase_check.present?
```

And if it passes, we create a set of Column book transfers that are essentially the reverse of what we created above. 

After this, the report will never be reimbursed.

\- [@sampoder](https://github.com/sampoder)
