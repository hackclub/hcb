# Follow-up: extracting a polymorphic `Grant` model

This is a design + migration plan for the refactor discussed in review of
[#13687](https://github.com/hackclub/hcb/pull/13687): introducing a `Grant`
model that belongs to either a card grant or a reimbursement report. It is
intentionally scoped as its **own PR**, separate from the feature work, for the
reasons in "Why not in #13687" below.

## Motivation

Today `CardGrant` conflates two concerns:

1. The **invitation / grant** itself: recipient, amount, purpose, expiration,
   instructions, acceptance methods, and the inherited event-level settings.
2. The **card fulfillment**: the Stripe card, subledger, and the spend that
   flows through it.

Once a recipient can accept a grant as a reimbursement report instead of a card
(#13687), concern (1) no longer belongs to the card. A dedicated `Grant`
aggregate that points at whichever fulfillment the recipient chose is cleaner
conceptually and removes the acceptance-method / settings ambiguity that
currently lives on `CardGrant`.

## Target shape

```
Grant
  belongs_to :event
  belongs_to :user
  belongs_to :sent_by, class_name: "User"
  belongs_to :grantable, polymorphic: true, optional: true # CardGrant | Reimbursement::Report
  # invitation data: amount_cents, email, purpose, expiration_at, instructions, invite_message
  # acceptance settings: allow_stripe_card, allow_reimbursement_report (nullable = inherit)
  # aasm_state: pending -> accepted_with_card | accepted_with_reimbursement | canceled | expired

CardGrant           # card fulfillment only: stripe_card, subledger, one_time_use, locks
Reimbursement::Report # unchanged; gains has_one :grant
```

`grantable` is `nil` while the invitation is pending and set once the recipient
accepts.

## What is implemented now

The `Grant` model and its wiring have landed (expand + backfill + dual-write):

- `grants` table and `Grant` model with `belongs_to :grantable, polymorphic:
  true` (a `CardGrant` or a `Reimbursement::Report`), plus `event` / `user` /
  `sent_by` and an AASM lifecycle (`pending` → `accepted_with_card` /
  `accepted_with_reimbursement` / `canceled` / `expired`).
- `CardGrant has_one :grant, as: :grantable` and the same on
  `Reimbursement::Report`.
- A `Grant` is created with every card grant and kept in sync at each
  transition: activation → `accepted_with_card`; cancel/expire → matching
  state; conversion repoints `grantable` to the new report and moves to
  `accepted_with_reimbursement`.
- A backfill seeds one `Grant` per existing grant (pointing at the report when
  it was accepted as a reimbursement, otherwise the card grant).

`CardGrant` is still the source of truth for invitation data (amount, email,
purpose, …); `Grant` currently delegates rather than owns it. That is the
deliberate dividing line below.

## Why the rest is a separate PR

`CardGrant` is referenced in ~212 files and backs ledgers, disbursements,
Stripe authorization, subledgers, metrics, the v4 API, jobs, and Wrapped.
Moving the invitation data off `card_grants` and repointing all of those reads
is the **contract** phase: a staged program with a production data migration
that would make the feature PR unreviewable if bundled in. It is described
under "Migration plan" below, steps 4-5.

## Migration plan (expand / migrate / contract)

Ship in small, independently-deployable steps; never a single cutover.

1. **Expand.** *(done)* Add the `grants` table and `Grant` model, and the
   `has_one :grant, as: :grantable` associations.
2. **Backfill.** *(done)* Seed one `Grant` per existing grant, pointing at the
   report if it was accepted as a reimbursement and otherwise the card grant,
   with `aasm_state` mapped from the current status. Idempotent and re-runnable.
3. **Dual-write.** *(done)* A `Grant` is created and transitioned alongside the
   `CardGrant` at every lifecycle step, so nothing that reads `CardGrant`
   breaks.
4. **Repoint reads incrementally.** *(remaining)* Move call sites from
   `card_grant.amount`, `.purpose`, `.user`, acceptance settings, etc. to
   `grant.*`, a directory at a time, leaning on delegation so each step is small
   and green.
5. **Contract.** *(remaining)* Once no code reads the duplicated concerns off
   `card_grants`, move invitation data onto `grants` and drop it from
   `card_grants`.

Each step is its own PR with its own tests; the app is shippable between every
step.

## Settings inheritance

Keep the two-level model established in #13687:

- `CardGrantSetting` holds the event-level **defaults** (concrete values).
- `Grant` stores **overrides**; a `NULL` acceptance method inherits the setting
  live (see `Grant#effective_allow_stripe_card`), exactly like merchant and
  category locks fall back to the setting today.

This is the piece Gary flagged as "complicates settings inheritance": the
resolution logic must live on `Grant` (the invitation), not on the fulfillment,
so both card and reimbursement fulfillments resolve settings the same way.

## State machine

`Grant` owns the acceptance lifecycle via AASM:

```
pending -> accepted_with_card          (recipient activates a virtual card)
pending -> accepted_with_reimbursement (recipient opens a reimbursement report)
pending -> canceled
pending -> expired
```

The `converted_to_reimbursement` state added to `CardGrant` in #13687 maps onto
`accepted_with_reimbursement` here and can be dropped from `CardGrant` in the
contract step.

## Risks

- **Data migration correctness.** Backfilling ~all historical grants; must be
  idempotent, batched, and verified against production counts before contract.
- **Dual-write drift.** While both models carry invitation data, a single
  source of truth (writes go through `Grant`) plus delegation avoids skew.
- **Read-path breadth.** The ~212 references are the bulk of the work; repoint
  them incrementally rather than in one PR.
- **API compatibility.** v4 exposes grant fields and `status`; version or
  document any shape change before the contract step.
