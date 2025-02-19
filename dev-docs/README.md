# All About HCB

HCB is a tool for hackers to hack on the real world, like GitHub, but for building with atoms and people, not bits and cycles. Thank you so much for contributing to the HCB database.

## Table of Contents
- [Home](#)
- [Development](./development.md)
- Guides
  - [Authentication](./guides/authentication.md)
  - [Card transactions](./guides/card_transactions.md)
  - [Fiscal sponsorship fees](./guides/fees.md)
  - [Fronted transactions](./guides/fronted_transactions.md)
  - [Fronted transactions](./guides/fronted_transactions.md)
  - [Reimbursements in the transaction engine](./guides/reimbursements_transaction_engine.md)
  - [Stripe payouts & fee reimbursements](./guides/stripe_payouts.md)
  - [Stripe service fees](./guides/stripe_service_fees.md)
  - [Transaction imports](./guides/transaction_imports.md)
  - [Wires](./guides/wires.md)
- [Admin tasks](./admin_tasks.md)
- [Post-mortems](./postmortems.md)
- [Pull requests](./pull_requests.md)

## Getting Started

Let's get the HCB codebase set up on your computer! We have setup a easy and simple [guide](./development.md) for you to get it running on your computer!

## HCB's Structure

We've been building HCB since 2018, navigating the codebase can be difficult at times. The codebase generally follows the [Model-View-Controller](https://developer.mozilla.org/en-US/docs/Glossary/MVC) design pattern, which Ruby on Rails is built around. If you need help, reach out to us in [#hcb-engr-help](https://hackclub.slack.com/archives/C068U0JMV19). ["Getting Started with Rails"](https://guides.rubyonrails.org/getting_started.html) is a comprehensive guide for first-time Rails developers.

### Organizations

Every project on HCB is considered an "organization" (the model for them is named `Event`, however). Users can be members of multiple organizations. `OrganizerPosition` acts as a [many-to-many](https://en.wikipedia.org/wiki/Many-to-many_(data_model)) join table between `Event` and `User`. `OrganizerPositionInvite` is a "pending" connection between the two, we create an `OrganizerPosition` after the user accepts the invite.

### Finances

Most financial transactions take place using our two bank accounts with [Column](https://column.com/). We also have bank accounts with Silicon Valley Bank ([funny story!](https://vtdigger.org/2023/03/17/vermont-based-hack-club-managed-to-move-its-money-out-of-silicon-valley-bank-before-it-closed/)) and TD Bank. 

We use [Stripe](https://stripe.com/) to enable invoice sending ([Stripe Invoicing](https://stripe.com/invoicing)), accept payments / donations ([Stripe Payments](https://stripe.com/payments)), and issue physical and virtual cards ([Stripe Issuing](https://stripe.com/issuing)).

Column is used to send checks, accept check deposits, send ACH transfers, generate an organization's account / routing number and create book transfers (these represent internal transfers). Refer to [Column's documentation](https://column.com/docs) for more information.

PayPal transfers are sent manually by HCB's operations staff. 

Disbursements are internal transfers from one organization to another. These are sometimes called “HCB transfers” in the interface.

Reimbursements are internal transfers to a "clearinghouse" organization on HCB which then sends an external transfer via ACH, check etc.

In the past, we've used [Increase](https://www.increase.com/), [Emburse](https://www.emburse.com/) and [Lob](https://www.lob.com/). We've also relied heavily on [Plaid](https://plaid.com/), however, we use it less nowadays. 

#### Receipts

Card transactions as well as ACHs, reimbursements, checks, and PayPal transfers require receipts. Models that allow adding receipts include the [`Receiptable`](https://github.com/hackclub/hcb/blob/main/app/models/concerns/receiptable.rb) concern. Receipt Bin is a tool created to manage "unlinked" receipts that haven't been paired to transactions, these receipts have their `receiptable_id` set to `nil`.

#### Fees

We collect fees on all revenue collected by organizations, typically 7%. This process is handled by a set of cron jobs and we make book transfers on our Column account to represent money moving from an organization's account to our operating fund.

### Transaction Engine

The transaction engine is the core of HCB's codebase. It's role is to map transactions that happen in on our underlying bank accounts to their associated organization. Almost every action a user takes on HCB will go through the transaction engine at some point.

Our transaction engine is summarised in [@sampoder](https://github.com/sampoder)'s talk at the SF Bay Area Ruby Meetup: [How we built a bank w/ Ruby on Rails](https://www.youtube.com/watch?v=CBxilReUkJ0&t=3553s).

#### [`CanonicalPendingTransaction`](https://github.com/hackclub/hcb/blob/main/app/models/canonical_pending_transaction.rb)

Canonical pending transactions are transactions we expect to take place but they haven't occurred yet in our underlying bank account. For example, we create a canonical pending transaction the moment you send an ACH transfer even though the transfer only gets sent via Column once a operations staff member has approved.

Canonical pending transactions appear on the ledger as "PENDING:" until a canonical transaction is made.

#### [`CanonicalTransaction`](https://github.com/hackclub/hcb/blob/main/app/models/canonical_transaction.rb)

Canonical transactions represent transactions that occur on our underlying bank account / show up on our bank statement. Our accountants and auditors rely on each transaction (including internal transfers) appearing on our bank statements. 

#### [`CanonicalPendingEventMapping`](https://github.com/hackclub/hcb/blob/main/app/models/canonical_pending_event_mapping.rb) / [`CanonicalEventMapping`](https://github.com/hackclub/hcb/blob/main/app/models/canonical_event_mapping.rb)

These models map canonical pending transactions and canonical transactions to their associated event.

#### [`CanonicalPendingSettledMapping`](https://github.com/hackclub/hcb/blob/main/app/models/canonical_pending_settled_mapping.rb)

A canonical pending settled mapping is created to match canonical pending transactions with canonical transactions when a transaction settles.

#### [`HcbCode`](https://github.com/hackclub/hcb/blob/main/app/models/hcb_code.rb)

HCB codes group together canonical transactions and canonical pending transactions into transactions we can display on the ledger. For example, a donation has a canonical transaction for both the money paid through the card and a refund for the Stripe processing fee. When we display a transactions, we display the HCB code.

#### Raw Transactions

Raw transactions, for example [`RawStripeTransaction`](https://github.com/hackclub/hcb/blob/main/app/models/raw_stripe_transaction.rb) or [`RawColumnTransaction`](https://github.com/hackclub/hcb/blob/main/app/models/raw_column_transaction.rb), represent the information we receive from external services such as Stripe or Column about transactions made through them.

For more extensive documentation on HCB's transaction engine, I recommend reading the guides linked above.

### Operations

HCB's operations team perform their work through the admin dashboard on HCB and an Airtable base. Financial operations take place on the admin dashboard. Meanwhile, promotions (eg. free 1Password) and applications (collected via [`hackclub/site`](https://github.com/hackclub/site)) are managed through the Airtable.

### Deployment & Monitoring

HCB is deployed on [Heroku](https://www.heroku.com/). We have two dynos, one for Rails and one for our [Sidekiq](https://github.com/sidekiq/sidekiq) workers. We handle errors using [Airbrake](https://www.airbrake.io/) and [AppSignal](https://www.appsignal.com/). We also run [status.hackclub.com](https://status.hackclub.com/) using [Checkly](https://www.checklyhq.com/).

***

![Laser cutting the HCB logo](https://cloud-kubwce40n-hack-club-bot.vercel.app/0hack_club_bank_laser.gif)
