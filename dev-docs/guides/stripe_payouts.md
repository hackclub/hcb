# Payouts & Fee Reimbursements: why are invoices and donations so damm complicated?
Good question. I guess I’ll do my best to explain them. There are two ways organisations can raise money through Stripe: invoices and donations. Invoices are created by an organisation and then sent, via Stripe, to the donor / sponsor. Meanwhile, to make a donation, donors head to HCB directly and enter their card details (a Stripe Elements form).

[`Invoice`](https://github.com/hackclub/hcb/blob/main/app/models/invoice.rb)s are created inside of [`InvoiceService::Create`](https://github.com/hackclub/hcb/blob/main/app/services/invoice_service/create.rb) which also creates the invoice on Stripe’s end. Learn more about [Stripe Invoicing](https://stripe.com/invoicing). Donations are created in [`DonationsController`](https://github.com/hackclub/hcb/blob/main/app/controllers/donations_controller.rb) and a `before_create` callback creates a Stripe payment intent for them. Once created in Stripe, they both can be found on https://dashboard.stripe.com/payments. 

Once a user pays a donation, we receive the `payment_intent.succeeded` webhook event from Stripe. Meanwhile, after an invoice is paid we receive `invoice.paid`. These are both handled in the [`StripeController`](https://github.com/hackclub/hcb/blob/main/app/controllers/stripe_controller.rb).

Once this is done, we create canonical pending transactions for either the invoice or the donation:

```ruby
::PendingTransactionEngine::RawPendingInvoiceTransactionService::Invoice::ImportSingle.new(invoice:).run

::PendingTransactionEngine::CanonicalPendingTransactionService::ImportSingle::Invoice.new(raw_pending_invoice_transaction: rpit).run

::PendingEventMappingEngine::Map::Single::Invoice.new(canonical_pending_transaction: cpt).run
```

```ruby
::PendingTransactionEngine::RawPendingDonationTransactionService::Donation::ImportSingle.new(donation:).run

::PendingTransactionEngine::CanonicalPendingTransactionService::ImportSingle::Donation.new(raw_pending_donation_transaction: rpdt).run

::PendingEventMappingEngine::Map::Single::Donation.new(canonical_pending_transaction: cpt).run
```

As you can see, it’s pretty similar for both donations and invoices. [`RawPendingInvoiceTransactionService`](https://github.com/hackclub/hcb/blob/main/app/services/pending_transaction_engine/raw_pending_invoice_transaction_service) and [`RawPendingDonationTransactionService`](https://github.com/hackclub/hcb/blob/main/app/services/pending_transaction_engine/raw_pending_donation_transaction_service) create one [`RawPendingInvoiceTransaction`](https://github.com/hackclub/hcb/blob/main/app/models/raw_pending_invoice_transaction.rb) or one [`RawPendingDonationTransaction`](https://github.com/hackclub/hcb/blob/main/app/models/raw_pending_donation_transaction.rb). These models will serve as the source for our [`CanonicalPendingTransaction`](https://github.com/hackclub/hcb/blob/main/app/models/canonical_pending_transaction.rb). For invoices, the `amount_cents` on [`RawPendingInvoiceTransaction`](https://github.com/hackclub/hcb/blob/main/app/models/raw_pending_invoice_transaction.rb) is `invoice.amount_paid`. This is because sponsors can underpay invoices if they pay via bank transfer.

We then import them in as CPTs, that’s the second service in the list. We use the details in [`RawPendingInvoiceTransaction`](https://github.com/hackclub/hcb/blob/main/app/models/raw_pending_invoice_transaction.rb) or [`RawPendingDonationTransaction`](https://github.com/hackclub/hcb/blob/main/app/models/raw_pending_donation_transaction.rb) to the set the `amount_cents` etc.

Next, we map these pending transactions and front them. This gives organisations instant access to the money, even though it isn’t technically in our bank account.

But now we need to get that money into our account and canonise this transaction.

The moment an invoice or donation is paid, Stripe will have created something called a balance transaction. It will have added money to our Stripe balance. We need to extract that money from our Stripe balance and into our bank balance (Column, at the time of writing).

For invoices, this takes starts in the [`InvoiceService::OpenToPaid`](https://github.com/hackclub/hcb/blob/main/app/services/invoice_service/open_to_paid.rb) service. This service sets `payout_creation_balance_net` and `payout_creation_balance_stripe_fee` on [`Invoice`](https://github.com/hackclub/hcb/blob/main/app/models/invoice.rb). `payout_creation_balance_net` is the amount paid into our Stripe balance, after Stripe subtracted their fees. `payout_creation_balance_stripe_fee` has the amount of fees Stripe subtracted. For example, if a sponsor paid a $50 invoice but Stripe took $2 in fees. `payout_creation_balance_net` will be `4800` and `payout_creation_balance_stripe_fee` would be `200`. That sums to `5000`. It also marks the invoice as `paid` (`mark_paid!`), allowing us to move to the next step. 

The equivalent logic for donations is handled in `Donation#set_fields_from_stripe_payment_intent!`. Donations at this time are marked as  `in_transit`. 

Next, we will create payouts from our Stripe balance. These payouts are a bank transfer from Stripe to Column. For both donations and invoices, this starts in [`PayoutService::Nightly`](https://github.com/hackclub/hcb/blob/main/app/services/payout_service/nightly.rb). This service queues [`Payout::DonationJob`](https://github.com/hackclub/hcb/blob/main/app/jobs/payout/donation_job.rb) and [`Payout::InvoiceJob`](https://github.com/hackclub/hcb/blob/main/app/jobs/payout/invoice_job.rb) which each call [`PayoutService::Donation::Create`](https://github.com/hackclub/hcb/blob/main/app/services/payout_service/donation/create.rb) and [`PayoutService::Invoice::Create`](https://github.com/hackclub/hcb/blob/main/app/services/payout_service/invoice/create.rb) respectively.

These create [`DonationPayout`](https://github.com/hackclub/hcb/blob/main/app/models/donation_payout.rb)s and [`InvoicePayout`](https://github.com/hackclub/hcb/blob/main/app/models/invoice_payout.rb)s. Both models have a `before_create` callback called `create_stripe_payout` that creates the payout from Stripe’s end.

The amount on these payments will both be:

```
payout_creation_balance_net + payout_creation_balance_stripe_fee
```

And they’ll be mapped to the invoice or donation’s HCB code using HCB short code mapping.

So how does HCB ensure that our balance doesn’t go negative? We then perform a top-up of our Stripe balance through a [`FeeReimbursement`](https://github.com/hackclub/hcb/blob/main/app/models/fee_reimbursement.rb).

> Funny name for that model? Yeah. In the past we’d make a book transfer to the organisation to cover the fee but switched to this model to reduce the complexity.

These [`FeeReimbursement`](https://github.com/hackclub/hcb/blob/main/app/models/fee_reimbursement.rb)s are created in [`PayoutService::Donation::Create`](https://github.com/hackclub/hcb/blob/main/app/services/payout_service/donation/create.rb) and [`PayoutService::Invoice::Create`](https://github.com/hackclub/hcb/blob/main/app/services/payout_service/invoice/create.rb). Their amount is simply `payout_creation_balance_stripe_fee`.

[`FeeReimbursementService::Nightly`](https://github.com/hackclub/hcb/blob/main/app/services/fee_reimbursement_service/nightly.rb) goes through these unprocessed [`FeeReimbursement`](https://github.com/hackclub/hcb/blob/main/app/models/fee_reimbursement.rb)s and makes top-ups to our Stripe balance through the [`StripeTopup`](https://github.com/hackclub/hcb/blob/main/app/models/stripe_topup.rb) model.

These are bank transfers from our bank account to Stripe’s bank account.

They will be mapped under a `HCB-900` which has all of the fee reimbursements from a certain week: https://hcb.hackclub.com/hcb/HCB-900-2024_50. Yes, that’s a lot of transactions. This is handled using HCB short codes.

This is one of the older parts of our codebase, so it’s a little clunky. Feel free to reach out ([@sampoder](https://github.com/sampoder)) with any questions.

## Recurring Donations

The weird child of invoices and donations. Recurring donations are Stripe invoices that get paid by customers every month, [`RecurringDonationService::HandleInvoicePaid`](https://github.com/hackclub/hcb/blob/main/app/services/recurring_donation_service/handle_invoice_paid.rb) creates a [`Donation`](https://github.com/hackclub/hcb/blob/main/app/models/donation.rb) from each invoice paid, which then is processed like a normal donation, as Stripe invoices also have payment intents.

\- [@sampoder](https://github.com/sampoder)
