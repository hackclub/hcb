# Migrating off the old transfer and tax systems

Two independent one-time migrations, each safe to run on its own.

## 1. Old transfer recipients into payees

`Maintenance::ImportPaymentRecipientPayeesTask` brings the old transfer system's
address book (`PaymentRecipient`) into the payee system, so those recipients stop
living behind their own picker and appear in the same list as everyone else.
`Payee#imported_at` is all that marks where they came from.

Per event, every recipient sharing an email becomes:

- one `Payee`, carrying only the name and email, with `imported_at` set;
- one managed `LegalEntity` for that payee, whose `managing_event` is the event;
- one `LegalEntity::PayoutMethod` per recipient, defaulting to whichever one
  money last actually went out on.

To run it, open `/maintenance_tasks`, pick the task, and run it. Notes:

- An email the payee flow already knows is skipped, so the task can be re-run
  after a partial failure without duplicating anything or overwriting payout
  details their owner has since entered themselves.
- Recipients whose saved details can no longer make a valid payout method (a
  malformed routing number, a wire missing a field today's validations require)
  are left behind; the payee is still created, just without that method.
- An imported legal entity has no `entity_type`: the old transfer records never
  said whether the recipient was a person or a business. It learns one from its
  first completed tax form.

## 2. Tax1099 certificates into HCB

Export **Reports > W8/W9 Report** from Tax1099, then:

```
rake 'tax1099:import[report.csv,dry_run]'   # reports what it would do, writes nothing
rake 'tax1099:import[report.csv]'
```

Each row becomes a completed manual `Tax::Form`, attached to the legal entity
that already carries its TIN, or to the filer's personal entity (SSN, W-8BEN) or
a new business entity (EIN, other W-8s), creating the user if they are new to
HCB. TaxBandits stays the source of truth: an imported form is dated to its
original filing and never outranks one filed since.

Two kinds of row are reported rather than filed, and need a human:

- a filer who already has a business legal entity, since which one the form
  belongs to is a judgement call;
- a row whose TIN disagrees with the entity that email already resolves to.
  Filing it anyway would make that entity permanently unpayable.

**The export contains raw SSNs.** Keep it on one machine, never commit it, never
put it on shared storage, and delete it once the run is finished. The importer
never logs or reports a TIN: everything it prints is keyed by row number and
email. Archive the signed PDFs out of Tax1099 before access to it lapses.
