# Fees Fees & Fees
HCB operates using a 7% fee on revenue. That’s easier to say, slightly harder to do.

### Who do we charge fees?
First thing we have to work out is who we need to charge fees (we charge fees weekly FYI). Here’s the SQL statement we use to do that:

```sql
;select event_id, fee_balance from (
select
q1.event_id,
COALESCE(q1.sum, 0) as total_fees,
COALESCE(q2.sum, 0) as total_fee_payments,
CEIL(COALESCE(q1.sum, 0)) + CEIL(COALESCE(q2.sum, 0)) as fee_balance

from (
    select
    cem.event_id,
    COALESCE(sum(f.amount_cents_as_decimal), 0) as sum
    from canonical_event_mappings cem
    inner join fees f on cem.id = f.canonical_event_mapping_id
    inner join events e on e.id = cem.event_id
    group by cem.event_id
) as q1 left outer join (
    select
    cem.event_id,
    COALESCE(sum(ct.amount_cents), 0) as sum
    from canonical_event_mappings cem
    inner join fees f on cem.id = f.canonical_event_mapping_id
    inner join canonical_transactions ct on cem.canonical_transaction_id = ct.id
    inner join events e on e.id = cem.event_id
    and f.reason = 'HACK CLUB FEE'
    group by cem.event_id
) q2

on q1.event_id = q2.event_id
) q3
where fee_balance != 0
order by fee_balance desc
```

Essentially, we calculate the total amount of fees we should have charged all-time and then the total amount of fees we’ve ever charged them all-time. If the difference is zero, we need to charge them fees (or give them a credit if we overcharged). 

A couple of things to note about this SQL query. Every time we create a `CanonicalEventMapping` we create a `Fee` record for that transaction that stores the fee that needs to be charged for that transaction.

These reason for this line:

```sql
and f.reason = 'HACK CLUB FEE'
```

Is that we create `Fee` records even for transactions that shouldn’t be charged a fee:

```ruby
enum :reason, {
    revenue: "REVENUE",                     
    # (Charges fee) Normal revenue
    donation_refunded: "DONATION REFUNDED", 
    # (Doesn't charge fee) Donation refunds
    hack_club_fee: "HACK CLUB FEE",         
    # (Doesn't charge fee) HCB fee transactions
    revenue_waived: "REVENUE WAIVED",       
    # (Doesn't charge fee) Revenue transactions with fee waived (either manually or automatically in certain cases)
    tbd: "TBD", 
   # (Doesn't charge fee) Everything else (including non-revenue)
}
```

You can use the `pending_fees_v2` scope to get a list of events that need to be charged a fee. There’s a five day minimum between charging fees.

### When do we charge them?

`BankFeeJob::Weekly` runs every week. It just calls `BankFeeService::Weekly`.

It runs through every event with pending fees, and creates one `BankFee` record per event. So this is this event’s “fee” for this week. It then creates one `FeeRevenue` that is HCB’s revenue for that week.

But these are just records in a database, they don’t appear on our bank statement. And that’s the number one rule of HCB, every transaction must appear on our bank statement. 

That’s the job of `BankFeeJob::Nightly` / `BankFeeService::Nightly`. 

It loops through the pending `BankFee`s and `FeeRevenue`s and creates Column transfers for them. It 99% of cases the flow looks like this:

```
(multiple) BankFee w/ a book transfer from FS Main to FS Operating
(single) FeeRevenue w/ a book transfer from FS Operating to FS Main
```

Because FS Operating sits at $0, all transfers to it must happen before money is withdrawn back into FS Main. However, as we’ll talk about later positive `BankFee`s exist (when someone is receiving a credit from us because we overcharged them). 

For these `BankFee`s, we’ll be doing a transfer from FS Operating to FS Main. That means they have to come after any transfers to FS Operating.

Similarly, that means there can technically be a negative `FeeRevenue` (when we are giving more credits than we earn). This is a FS Main to FS Operating transfer and must come before any transfers to FS Main.

This is the reason for the `bank_fees_to_main` and `fee_revenues_to_main` arrays in this service. All transfers into FS Operating come before transfers back into FS Main.

We then use HCB short code mapping to make sure these get mapped to the right event / HCB code. View my guide on transaction importing for more.

### Pending fees

Ok but… if we only charges fees every week, someone could theoretically overspend? Yes, but we’ve prevented that. Firstly, `Event#balance_available_v2_cents` subtracts `Event#fee_balance_v2_cents` which is previously described difference in fees owed all-time and fees paid all-time. And, secondly, we render a fake pending transaction on the top of the ledger that shows the pending fee payment. It’s partial is `events/pending_fee_transaction`.

### Fee Credits & Fee Waivers

At times, we may want to waive fees on revenue. For example, if the transaction is a refund or if it’s the initial transfer of money into their account.

There are two ways of waiving fees, set `fee_waived` on the `CanonicalPendingTransaction` or set `reason` on the `Fee` to “TBD”.

Occasionally, we make this waiver after charging a fee. This results in a fee credit. Which is essentially a fee where we (HCB) pay the organisation instead of them paying us.

\- [@sampoder](https://github.com/sampoder)
