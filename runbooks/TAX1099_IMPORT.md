# Importing Tax1099 certificates into HCB

A one-time migration of the tax paperwork HCB collected through Tax1099, run
when TaxBandits took over. Export **Reports > W8/W9 Report** from Tax1099, then:

```
rake 'tax1099:import[report.csv,dry_run]'   # reports what it would do, writes nothing
rake 'tax1099:import[report.csv]'
```

Each row becomes a completed manual `Tax::Form`, attached to the legal entity
that already carries its TIN, or to the filer's personal entity (SSN, W-8BEN) or
a new business entity (EIN, other W-8s), creating the user if they are new to
HCB. TaxBandits stays the source of truth: an imported form is dated to its
original filing and never outranks one filed since.

## Rows that need a human

Two kinds of row are reported rather than filed:

- a filer who already has a business legal entity, since which one the form
  belongs to is a judgement call;
- a row whose TIN disagrees with the entity that email already resolves to.
  Filing it anyway would make that entity permanently unpayable.

## Handling the file

**The export contains raw SSNs.** Keep it on one machine, never commit it, never
put it on shared storage, and delete it once the run is finished. The importer
never logs or reports a TIN: everything it prints is keyed by row number and
email. Archive the signed PDFs out of Tax1099 before access to it lapses.
