# Wires on HCB
Wires are our most complex outbound transfer type. That’s largely due to requirements varying from country to country. Before reading this, I’d recommend [Column’s documentation on wires](https://column.com/docs/international-wires/). Specifically the section on “Country-specific Details” and “Outgoing Transfers”.Our system is largely modelled on theirs.

## The basics

Wires are sent via Column, just like ACH transfers and checks. They use HCB code “HCB-310”. They’re sent from each organisation’s Column-issued account number and that is used to map them to their organisation.

## How we handle currency

Column provides us with currency exchange, we choose not to take a quote and instead accept whatever rate they currently have. The 	`CanonicalTransaction` produced from sending a wire represents us using USD to purchase the currency we need to send the wire.

Wires also have an associated `CanonicalPendingTransaction`, the `amount_cents` for that transaction is in USD and is based on exchange rates from the EU central bank at the time of creation.

The most up to date amount for a wire (in USD) is accessible using `Wire#usd_amount_cents`. `Wire#amount_cents` and `Wire#currency` store the currency and amount of the wire, in that currency.

## How we collect specific country fields

Column lists out the specific details needed for a wire in each country: [column.com/docs/international-wires/country-specific-details](https://column.com/docs/international-wires/country-specific-details).

We’ve translated this into the `Wire#information_required_for` method. Which you pass in a country code and are returned an array of details that need to be collected. This information is stored in the `recipient_information` JSONB column of the database, we use [`ActiveRecord::Store`](https://api.rubyonrails.org/classes/ActiveRecord/Store.html) for this. On the frontend, we conditionally render these fields using Alpine based on the recipient’s country. 

We then pass this information to Column, but directly reference the fields because they have to go in specific spots in the request body. When adding a new field, we have to add it to the calls to Column.

## When wires go wrong

The recipient bank may reject a wire, it’ll be sent back to Column and then sent back to us. In India, this is often because of an invalid purpose code. Try and be as specific as possible with purpose codes. The bank’s reason for rejecting the wire will be stored in the `return_details` on Column. When wires are returned, we will lose a bit of money because of currency exchange. This will be reflected as the “Settled amount” on a wire.

\- [@sampoder](https://github.com/sampoder)
