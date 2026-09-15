# Importing old transfer recipients into payees

`Maintenance::ImportPaymentRecipientPayeesTask` brings the old transfer system's
address book (`PaymentRecipient`) into the payee system, so those recipients stop
living behind their own picker and appear in the same list as everyone else.
`Payee#imported_at` is all that marks where they came from.

Per event, every recipient sharing an email becomes:

- one `Payee`, carrying only the name and email, with `imported_at` set;
- one managed `LegalEntity` for that payee, whose `managing_event` is the event;
- one `LegalEntity::PayoutMethod` per recipient, defaulting to whichever one
  money last actually went out on.

To run it, open `/maintenance_tasks`, pick the task, and run it.

## Notes

- An email the payee flow already knows is skipped, so the task can be re-run
  after a partial failure without duplicating anything or overwriting payout
  details their owner has since entered themselves.
- Recipients whose saved details can no longer make a valid payout method (a
  malformed routing number, a wire missing a field today's validations require)
  are left behind; the payee is still created, just without that method.
- An imported legal entity has no `entity_type`: the old transfer records never
  said whether the recipient was a person or a business. It learns one from its
  first completed tax form, and until then no form can contradict it.
- A recipient with no email is skipped entirely, since a payee cannot exist
  without one.
