# Payouts & Fee Reimbursements: why are invoices and donations so damm complicated?
Good question. I guess I’ll do my best to explain them. There are two ways organisations can raise money through Stripe: invoices and donations. Invoices are created by an organisation and then sent, via Stripe, to the donor / sponsor. Meanwhile, to make a donation, donors head to HCB directly and enter their card details (a Stripe Elements form).

`Invoice`s are created inside of `InvoiceService::Create` which also creates the invoice on Stripe’s end. Learn more about [Stripe Invoicing](https://stripe.com/invoicing). Donations are created in `DonationsController` and a `before_create` callback creates a Stripe payment intent for them. Once created in Stripe, they both can be found on https://dashboard.stripe.com/payments. 

Once a user pays a donation, we receive the `payment_intent.succeeded` webhook event from Stripe. Meanwhile, after an invoice is paid we receive `invoice.paid`. These are both handled in the `StripeController`.

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

As you can see, it’s pretty similar for both donations and invoices. `RawPendingInvoiceTransactionService` and `RawPendingDonationTransactionService` create one `RawPendingInvoiceTransaction` or one `RawPendingDonationTransaction`. These models will serve as the source for our Canonical Pending Transaction. For invoices, the `amount_cents` on `RawPendingInvoiceTransaction` is `invoice.amount_paid`. This is because sponsors can underpay invoices if they pay via bank transfer.

We then import them in as CPTs, that’s the second service in the list. We use the details in `RawPendingInvoiceTransaction` or `RawPendingDonationTransaction` to the set the `amount_cents` etc.

We then map these pending transactions and front them. This gives organisations instant access to this money, even though it isn’t technically in our bank account.

But now we need to get that money into our account and canonise this transaction.

The moment an invoice or donation is paid, Stripe will have created something called a balance transaction. It will have added money to our Stripe balance. We need to extract that money from our Stripe balance and into our bank balance (Column, at the time of writing).

For invoices, this takes starts in the `InvoiceService::OpenToPaid` service. This service sets `payout_creation_balance_net` and `payout_creation_balance_stripe_fee` on `Invoice`. `payout_creation_balance_net` is the amount paid into our Stripe balance, after Stripe subtracted their fees. `payout_creation_balance_stripe_fee` has the amount of fees Stripe subtracted. For example, if a sponsor paid a $50 invoice but Stripe took $2 in fees. `payout_creation_balance_net` will be `4800` and `payout_creation_balance_stripe_fee` would be `200`. That sums to `5000`. It also marks the invoice as `paid` (`mark_paid!`), allowing us to move to the next step. 

The equivalent logic for donations is handled in `Donation#set_fields_from_stripe_payment_intent!`. Donations at this time are marked as  `in_transit`. 

Next, we will create payouts from our Stripe balance. This payouts are a bank transfer from Stripe to Column. For both donations and invoices, this starts in `PayoutService::Nightly`. This service queues `Payout::DonationJob` and `Payout::InvoiceJob` which each call `PayoutService::Donation::Create` and `PayoutService::Invoice::Create` respectively.

These create `DonationPayout`s and `InvoicePayout`s. Both models have a `before_create` callback called `create_stripe_payout` that creates the payout from Stripe’s end.

The amount on these payments will both be:

```
payout_creation_balance_net + payout_creation_balance_stripe_fee
```

And they’ll be mapped to the invoice or donation’s HCB code using HCB short code mapping.

So how does HCB ensure that our balance doesn’t go negative? We then perform a top-up of our Stripe balance through a `FeeReimbursement`.

> Funny name for that model? Yeah. In the past we’d make a book transfer to the organisation to cover the fee but switched to this model to reduce the complexity.

These `FeeReimbursement`s are created in `PayoutService::Donation::Create` and `PayoutService::Invoice::Create`. Their amount is simply `payout_creation_balance_stripe_fee`.

`FeeReimbursementService::Nightly` goes through these unprocessed fee reimbursements and makes top-ups to our Stripe balance through the `StripeTopup` model.

These are bank transfers from our bank account to Stripe’s bank account.

They will be mapped under a `HCB-900` which has all of the fee reimbursements from a certain week: https://hcb.hackclub.com/hcb/HCB-900-2024_50. Yes, that’s a lot of transactions. This is handled in `EventMappingEngine::Nightly#map_outgoing_fee_reimbursements!`

This is one of the older parts of our codebase, so it’s a little clunky. Feel free to reach out (@sampoder) with any questions.

## Recurring Donations

The weird child of invoices and donations. Recurring donations are Stripe invoices that get paid by customers every month, `RecurringDonationService::HandleInvoicePaid` creates a `Donation` from each invoice paid, which then is processed like a normal donation. As Stripe invoices also have payment intents.

\- [@sampoder](https://github.com/sampoder)
