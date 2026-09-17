# Importing old transfer recipients into payees

`Maintenance::ImportPaymentRecipientPayeesTask` brings the old transfer system's
address book (`PaymentRecipient`) into the payee system, so anyone an org has
sent a transfer to before shows up in the payee picker alongside everyone else.
Nothing in the UI distinguishes an imported payee; `Payee#imported_at` only
records where it came from.

Per event, every recipient sharing an email becomes:

- one `Payee`, carrying only the name and email, with `imported_at` set;
- one managed `LegalEntity` for that payee, whose `managing_event` is the event;
- one `LegalEntity::PayoutMethod` per distinct set of payout details, defaulting
  to whichever one money last actually went out on.

To run it, open `/maintenance_tasks`, pick the task, and run it.

## Notes

- **The payee system wins every conflict.** An email the payee flow already
  knows is skipped outright, whatever the old system recorded against it. That
  is also what lets the task be re-run after a partial failure without
  duplicating anything or overwriting details their owner has since entered.
- `payment_recipients` is not only the old address book: `HasPaymentRecipient`
  writes a row behind *every* ACH transfer, check, and wire, including the ones
  the modern payout system, reimbursements, and payroll create. So the import
  sees the same account many times over, and collapses repeats into one payout
  method. Rows belonging to an existing payee are skipped by the rule above.
- Recipients whose saved details can no longer make a valid payout method (a
  malformed routing number, a state stored as "California" rather than "CA", a
  wire missing a field today's validations require) are left behind; the payee
  is still created, just without that method. Each one is logged with
  `[ImportPaymentRecipientPayees]` and the recipient id — grep the run's logs
  afterwards, because nothing about the payee itself says a method went missing.
- Validating a wire calls Column (`/institutions/:bic_code`) to find out what
  country the bank is in, so wire recipients cost a handful of API calls each,
  and a wire Column reports as US-domiciled is rejected. If Column is
  unreachable the validation falls back to the recipient's own country, which
  means a wire's importability can differ between runs. Check Column is healthy
  before running, and prefer one run to many.
- An imported legal entity has no `entity_type`: the old transfer records never
  said whether the recipient was a person or a business. It learns one from its
  first completed tax form, and until then no form can contradict it.
- A recipient with no email is skipped entirely, since a payee cannot exist
  without one. A recipient nobody ever named is titled by its email, which is
  also what gets sent to TaxBandits as the legal entity's name.
