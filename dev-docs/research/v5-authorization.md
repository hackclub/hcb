# v5 API Authorization: Field-Level & Index-Route Policy

**Status:** research / proposal. Nothing here is implemented yet.

v5 is meant to be "v4's features with v3's transparency". The blocker is
authorization. Pundit today answers *"may this user touch this record?"* It does
not answer *"may this user see the account number **on** this record?"*, and that
second question is the whole difference between a v4 response (only members ever
see the object) and a v5 response (anyone may see a transparent org's objects, but
with different fields).

The hard requirement is that **v5 and the web UI must be unable to drift**. This
document audits what we have, explains why `permitted_attributes` alone doesn't get
us there, and proposes a design.

## Table of Contents

- [Where We Are Today](#where-we-are-today)
  - [Three parallel authorization systems](#three-parallel-authorization-systems)
  - [How v3 handles field visibility](#how-v3-handles-field-visibility)
  - [How v4 handles field visibility](#how-v4-handles-field-visibility)
  - [Index routes: three approaches, none of them Pundit's](#index-routes-three-approaches-none-of-them-pundits)
- [Where `permitted_attributes` Lands](#where-permitted_attributes-lands)
- [Proposal](#proposal)
  - [1. One principal, not one policy per surface](#1-one-principal-not-one-policy-per-surface)
  - [2. `visible_attributes`: a per-viewer list of field names](#2-visible_attributes-a-per-viewer-list-of-field-names)
  - [3. Deny by default, enforced by the serializer](#3-deny-by-default-enforced-by-the-serializer)
  - [4. Index routes: actually use `policy_scope`](#4-index-routes-actually-use-policy_scope)
- [Pilot Implementation](#pilot-implementation)
- [Alternatives Considered](#alternatives-considered)
- [Migration Plan](#migration-plan)
- [Open Questions](#open-questions)

---

## Where We Are Today

### Three parallel authorization systems

We have three, and they already disagree with each other.

| | Policy source | Principal | Field visibility |
|---|---|---|---|
| **Web** | `app/policies/*` (73 files) | `current_user` (`User` or `nil`) | ad hoc `if policy(x).y?` in ERB |
| **v3** | `app/policies/api/*` (16 files) | always literally `nil` | baked into the Grape entity's shape |
| **v4** | `app/policies/*`, but via forked `*_in_v4?` methods | `ApiAdminContext` wrapping user + token | ad hoc `if policy(x).y?` in jbuilder |

Two specific divergences are worth naming, because they're the ones v5 has to
resolve rather than inherit:

**The `Api::` policy namespace is a shadow copy.** `app/policies/api/event_policy.rb`
reimplements a dozen predicates as `record.is_public?`, and v3 authorizes with a
hardcoded nil user:

```ruby
# app/api/api/v3.rb:294
Pundit.authorize(nil, [:api, org], :show?)
```

Passing `nil` isn't a bug — v3 is a public API, so every request is anonymous by
design. But it means `Api::EventPolicy` is a *second, unrelated* statement of what
"public" means, sitting next to `EventPolicy#show?`, with nothing keeping the two
in sync.

**`*_in_v4?` is the same fork by another name.** Compare:

```ruby
# app/policies/event_policy.rb:13
def show?
  is_public || auditor_or_reader?
end

# app/policies/event_policy.rb:17
def show_in_v4?
  auditor_or_reader?
end
```

There are 9 of these (`index_in_v4?`, `show_in_v4?`, `transfers_in_v4?`,
`card_overview_in_v4?`, `sub_organizations_in_v4?`, `InvoicePolicy#show_in_v4?`, …).
Every one exists to strip the `is_public ||` clause. That is precisely the clause v5
wants back. If we let this pattern continue we'll be writing `show_in_v5?` next
quarter and we'll have four systems instead of three.

**And a large amount of authorization isn't in Pundit at all.** `organizer_signed_in?`
(`app/helpers/sessions_helper.rb:126`) is called **151 times across 81 view files**, and
`OrganizerPosition.role_at_least?` is called **120 times** across the app. These
encode the same role lattice the policies encode, in a place the API can't reach —
which is *why* the API reimplements it.

### How v3 handles field visibility

It doesn't, really — it sidesteps the problem. A Grape entity has exactly one
shape, and that shape is the anonymous-public shape:

```ruby
# app/api/api/entities/ach_transfer.rb
when_expanded do
  expose :amount, as: :amount_cents
  expose :aasm_state, as: :status
  expose :beneficiary do
    expose :recipient_name, as: :name
  end
end
```

There is no `account_number` here and there never can be, because there's no viewer
to ask about. Safe, and completely unable to serve a manager who legitimately needs
the routing number. **v3's field safety is structural, not policy-driven** — which
is exactly why it can't be the v5 answer.

### How v4 handles field visibility

Ad hoc, inline, opt-in. Across all of `app/views/api/v4/` there are **12 conditional
field checks in 9 files**:

```ruby
# app/views/api/v4/transactions/_ach_transfer.json.jbuilder:10
if policy(ach_transfer).view_account_routing_numbers?
  json.account_number_last4 ach_transfer.account_number.slice(-4, 4)
  json.routing_number ach_transfer.routing_number
end
```

The good news: this is already the right *idea*, and it's already shared with the
web UI. The identical check appears at
`app/views/hcb_codes/transaction_types/_ach_transfer.html.erb:66`, calling the same
`AchTransferPolicy#view_account_routing_numbers?`
(`app/policies/ach_transfer_policy.rb:20`). So "one policy predicate consumed by both
ERB and the serializer" is a pattern we already run in production — it just has no
name, no enforcement, and only 12 instances.

The bad news is everything else about it:

- **It's opt-in.** Nothing stops the next `json.foo` line from shipping a field
  nobody authorized. The failure mode is silent and it's a data leak.
- **There's no inventory.** You cannot answer "what does a reader see on an ACH
  transfer?" without reading every partial that renders one.
- **Some of it isn't policy at all.** `expand_pii`
  (`app/helpers/api/v4/application_helper.rb:104`) gates on token scope + admin
  level directly, and `_user.json.jbuilder` layers `user == current_user` on top of
  it inline. That logic is unreachable from ERB.

### Index routes: three approaches, none of them Pundit's

1. **Authorize the parent, hand-scope the association** —
   `authorize @event, :index_in_v4?` then `@event.tags`. Used by tags, sponsors,
   check_deposits, donations, organizer_positions.
2. **`skip_authorization` + hand-scope off `current_user`** —
   `app/controllers/api/v4/events_controller.rb:10` does
   `current_user.events.not_hidden`; `receipts_controller.rb:12` does
   `Receipt.in_receipt_bin.where(user: current_user)`.
3. **Authorize a *different* record, then read through it** —
   `receipts_controller.rb:9` authorizes the `HcbCode` and returns
   `@hcb_code.receipts`.

Approach 2 is the dangerous one: `skip_authorization` disables the
`verify_authorized` safety net entirely, and correctness then rests on a hand-written
scope in a controller that no policy spec covers.

Meanwhile Pundit's actual answer to this is `policy_scope`, and we use it in **two
places** (`app/controllers/api/v4/comments_controller.rb:8` and two comment
partials). There is exactly **one** `Scope` class in the entire app —
`CommentPolicy::Scope`. `ApplicationPolicy::Scope#resolve` returns the scope
unfiltered (`app/policies/application_policy.rb:47`).

This matters doubly for v5, because transparency is *fundamentally* a scoping
question. v3 already knows this — it just hardcodes it in the API layer instead of
a policy:

```ruby
# app/api/api/v3.rb
Event.indexable   # ...
Event.transparent.find_by_public_id id
```

---

## Where `permitted_attributes` Lands

A policy-owned declaration of which fields a viewer may see is the right shape,
and a **list of field names** carries most of it. Counting `app/views/api/v4/`:

| | count |
|---|---|
| Total field emissions | ~300 |
| Inside some conditional (gated presence) | ~64 (~20%), across 9 files |
| Value-degradation (present, but a different value) | **2** |

So ~99% of the surface is presence, which a list expresses directly. Two things
keep it from being *Pundit's* `permitted_attributes` specifically, and one case
a list cannot express at all.

**Use a different method name.** Pundit's `permitted_attributes` is a
strong-parameters helper for *input*, and we use it that way today:
`SponsorPolicy#permitted_attributes` (`app/policies/sponsor_policy.rb:33`)
returns `:id` and conditionally `:event_id` and feeds `params.permit` at
`sponsors_controller.rb:69` and `invoices_controller.rb:236`. Overloading it for
output would either permit read-only fields as writable or leak write-only
semantics into the contract. `permitted_attributes_for_<action>` doesn't rescue
this: Pundit keys it on `params[:action]`, and a nested partial has no action of
its own — a user rendered inside a transaction inside an index resolves against
`index`. Serializers are recursive; the action-keyed variant assumes one record
per request. So: same idea, named `visible_attributes`.

**A list cannot express a masked value.** It is binary — the symbol is in or
out. It has nothing to say about a field that is always *present* but carries a
different value per viewer. That is exactly what "transparency mode should hide
full names" means: `name` doesn't disappear, it degrades to
`User#initial_name` (`app/models/user.rb:343`) — "Mohamad A." rather than the
full name. Dropping the key instead is not a free workaround, because v3 always
returns a name and every transparency client would break on the missing key.
The same shape appears in the UI at `app/views/events/account_number.html.erb:38,48`,
which renders `"•" * account_number.length` rather than omitting the row.

For those, the policy keeps a **named predicate** (`UserPolicy#full_name?`) and
the serializer picks the value. The policy still makes the decision; only the
rendering differs. There is essentially one such case in the current surface.

> **A live exposure, found while counting.** `Api::Entities::User` does
> `expose :name, as: :full_name` with no gating, and v3 authorizes anonymously.
> We currently publish the full legal name of every member of a transparent
> organization to unauthenticated callers. Hiding names is listed as a v5 goal;
> it is a v3 bug today.

---

## Proposal

Four changes. (1) and (4) are independently valuable and can land before v5
exists. A working pilot of (1)-(3) is on this branch — see
[Pilot Implementation](#pilot-implementation).

### 1. One principal, not one policy per surface

`show_in_v4?` exists because v4 didn't want anonymous transparency. But that
isn't a different *rule*, it's a different *actor*. We already have the right
shape — `ApiAdminContext` (`app/models/api_admin_context.rb`) is a principal
object that ANDs `admin?`/`auditor?` with token scopes so policies don't have to
know about tokens. Generalize it to carry the surface and an optional token, and
**delete every `*_in_v4?` method and the whole `app/policies/api/` namespace.**

> **The objection, and the answer.** "But then an OAuth app granted
> `organizations:read` for one user could walk every transparent org." True, and
> that's a real concern — but it is a **token** concern, not a **user** concern.
> `dev-docs/v4-api/scopes.md` states the split: *"Scopes restrict tokens;
> policies restrict users."* The fix is a `transparency:read` scope, not a
> forked policy method. The `_in_v4?` family was scope enforcement smuggled into
> the policy layer.

### 2. `visible_attributes`: a per-viewer list of field names

```ruby
class AchTransferPolicy < ApplicationPolicy
  def visible_attributes
    attrs = []
    if transparent_or_reader?
      attrs += %i[amount_cents date status recipient_name payment_for sender]
      attrs += %i[recipient_email bank_name] if auditor_or_user?
      attrs += %i[account_number account_number_last4 routing_number] if view_account_routing_numbers?
    end
    attrs
  end
end
```

Names are keys in the **output contract**, not model attributes — which is what
makes derived values (`:account_number_last4`), externally-fetched ones (a TIN
last-4 from TaxBandits), and nested blocks (`:sender`) all expressible.

The predicates are the ones the policies already have; nothing new is invented,
and only the *gated* fields need naming — not all 300.

### 3. Deny by default, enforced by the serializer

This is the actual safety property, and it matters more than list-vs-predicate.
Serializers write through an `Api::FieldSet` rather than to `json` directly, and
a field the policy doesn't list is never emitted. Forgetting to declare a field
becomes a missing-data bug (loud, harmless) instead of a leak (silent, not).

That is not hypothetical: `json.bank_name` is ungated in v4 today while the web
UI masks it to `"Sign in to view"` (`_ach_transfer.html.erb:63`). Nobody decided
that — someone just didn't add an `if`.

**Object-level read authorization falls out of the same list.** If a viewer can
see no attribute, there is nothing to serve:

```ruby
def show_any_attribute?
  visible_attributes.any?
end
```

That is what replaces `*_in_v4?`. A new API surface changes which *fields* it
asks for, never which policy *method* it calls.

**The web side reads the same list**, via a `visible?(record, attribute)` view
helper. ERB has no mechanical output contract, so there is nothing to
auto-filter — and it doesn't need it. What prevents drift isn't that both sides
filter identically; it's that **both read one declaration.**

### 4. Index routes: actually use `policy_scope`

Replace all three current approaches with the one Pundit ships:

```ruby
after_action :verify_authorized
after_action :verify_policy_scoped, only: :index
```

Every index becomes `policy_scope(Model)`, and each policy grows a real
`Scope#resolve`. **`skip_authorization` in an index action becomes a lint
failure.** This also solves transparency for index routes for free — the
anonymous branch of a `Scope` is exactly the `Event.transparent` filter v3
hardcodes today.

**Performance caveat, and it's a real one.** `Scope#resolve` must return SQL,
but our role checks are Ruby walking `ancestor_organizer_positions`, and event
visibility already involves a recursive CTE (`app/models/event.rb:236-247`).
Plan for an `Event.visible_to(user)` SQL scope called from `Scope#resolve`, with
a spec asserting `Model.visible_to(u).include?(r) == policy(u, r).show?` over a
sample. That equivalence test is what keeps the Ruby and SQL paths honest.

---

## Pilot Implementation

A working vertical slice is on this branch: ACH transfers (presence tiers) and
users (the one masking case), served by a real endpoint.

| File | Role |
|---|---|
| `app/policies/application_policy.rb` | `visible_attributes` (defaults to `[]`), `visible?`, `show_any_attribute?` |
| `app/lib/api/field_set.rb` | the deny-by-default emitter |
| `app/policies/ach_transfer_policy.rb` | presence tiers |
| `app/policies/user_policy.rb` | `visible_attributes` + `full_name?` (masking) |
| `app/helpers/api/v5/application_helper.rb` | `object_shape` yielding a `FieldSet` |
| `app/helpers/application_helper.rb` | `visible?(record, attribute)` for ERB |
| `app/views/api/v5/**` | v5 serializers |
| `app/controllers/api/v5/**` | `GET /api/v5/ach_transfers/:id`, anonymous allowed |

A serializer looks like this — note that `json` is never written to directly:

```ruby
object_shape(json, ach_transfer) do |f|
  f.recipient_name ach_transfer.recipient_name
  f.bank_name ach_transfer.bank_name
  f.routing_number ach_transfer.routing_number
  # Block form: the account number is an encrypted column, so a viewer who
  # can't see this field never pays to decrypt it.
  f.account_number_last4 { ach_transfer.account_number.slice(-4, 4) }
  f.nest(:sender) { json.partial! "api/v5/users/user", user: ach_transfer.creator }
end
```

One serializer, and the response varies by viewer:

| Viewer | Keys returned |
|---|---|
| Anonymous, private org | *403* |
| Anonymous, transparent org | `id object amount_cents date status recipient_name payment_for sender created_at` |
| Reader | + `recipient_email bank_name` |
| Manager / admin | + `routing_number account_number_last4` |

and the nested sender's `name` degrades to `"Jane D"` outside the viewer's
organizations while staying present.

### Verification

| Spec | Covers |
|---|---|
| `spec/lib/api/field_set_spec.rb` | gating, deferred values, arity, Object-method name collisions |
| `spec/policies/ach_transfer_policy_spec.rb` | every role tier, and `show_any_attribute?` |
| `spec/controllers/api/v5/ach_transfers_controller_spec.rb` | end to end: exact key sets per viewer, name degradation, anonymous access |

> These specs have **not been executed** — they were written in an environment
> without the gem bundle (Ruby 3.3 against a 3.4.9 Gemfile, no Rails). The
> `FieldSet` semantics and the `AchTransferPolicy` tiers were verified
> separately by loading those two files under plain Ruby with the Rails
> dependencies stubbed. Run the suite before trusting the rest.

### Notes from building it

- **`v5` allows anonymous requests.** A *missing* token is fine (transparency);
  a *malformed* one is still a 401. That is the whole v3-parity change, and it
  needed no new policy method.
- **`FieldSet` is a blank slate.** Field names come from the API contract and
  some collide with inherited Object methods — `f.display "..."` would call
  `Kernel#display`, silently, for that name only. Every public method outside a
  small allowlist is undefined so all field names route through
  `method_missing`.
- **Arity is validated before the visibility check**, so a malformed serializer
  call fails for every viewer rather than only the roles that can see it.
- **`:account_number` and `:account_number_last4` are both listed** under one
  permission, because the web UI reveals the full number to a manager while the
  API ships four digits. That split predates this work and nobody recorded
  whether it was deliberate. Listing both preserves today's behavior and makes
  the difference visible in one place instead of two templates. **This needs a
  decision** (see Open Questions).

### Caveats to hold the design to

1. **Per-surface field names would re-fork it.** `:account_number` vs
   `:account_number_last4` is the existing instance. Rule to adopt: the same
   field name on both surfaces, or it's a bug.
2. **N+1 risk, and the list makes it systematic.** `visible_attributes` calls
   `role_at_least?(user, record.event, …)` per record; a 100-row page is 100
   role lookups plus one per nested user and event. Already true of the 12
   inline checks today, but this would be on every object.
   `User#readable_event_ids` is memoized here as a start;
   `UserPolicy#shares_org_with_viewer?` uses `map` rather than `pluck` so a
   preload actually helps. Index routes must preload before this ships widely.
3. **Nested objects have no `authorize` call.** For a sender or an org rendered
   inside a transaction, the list is the *only* gate. `visible_attributes == []`
   renders as bare `id`/`object`, matching v3's minimized shape — deliberate,
   and worth confirming per object.

## Alternatives Considered

**CanCanCan.** Genuinely has field-level abilities
(`can :read, AchTransfer, [:routing_number]`) — the only mainstream Rails option
that does. Rejected: swapping the authorization framework across 73 policies and
150+ view call sites is a far larger change than the problem warrants, and its
field support is still attribute-oriented, so it doesn't help with derived fields,
TaxBandits values, or nested blocks — the cases that actually hurt.

**action_policy.** Nicer than Pundit on two axes we care about: first-class
*authorization contexts* (would model `Principal` cleanly) and better scoping
ergonomics. But it has no field-level story either, so we'd still be building
section 2 by hand — on top of a full framework migration. Worth revisiting if we
ever migrate for other reasons; not worth migrating *for* this.

**A `field :x, visible_to: :predicate?` declaration DSL** (an earlier draft of
this document). Rejected on the numbers: 2 of ~300 fields need masking, so
building a declaration mechanism to handle 0.7% of cases is the wrong trade, and
it puts a line in every policy for every field. A list plus one predicate for
the masking case covers the same ground with far less machinery.

**Per-viewer serializer variants** (v3's approach, generalized:
`PublicAchTransferEntity` vs `MemberAchTransferEntity`). Rejected: combinatorial
explosion at ~6 viewer levels × nested objects, and duplicated shapes are precisely
the mechanism that let v3 and v4 drift in the first place.

**Status quo — keep writing inline `if policy(x).y?`.** Works, and is already
shared with ERB in the ACH case. Rejected only because it's opt-in: the failure
mode of forgetting is a silent PII leak, and v5 multiplies the surface by serving
anonymous viewers.

---

## Migration Plan

Sequenced so nothing blocks the v3-serializer-on-the-ledger-engine work already in
flight.

**Phase 0 — pilot, one object end to end. ✅ done on this branch.** See
[Pilot Implementation](#pilot-implementation). `visible_attributes` +
`Api::FieldSet` applied to `AchTransferPolicy` and `UserPolicy`, consumed by both
a v5 serializer and the existing ERB view, behind a real endpoint. `Principal` is
*not* built yet — the pilot reuses `ApiAdminContext` and permits anonymous
requests at the controller, which was enough to prove transparency works without
a `show_in_v5?`.

**Phase 1 — `Scope` classes + `verify_policy_scoped`,** on the indexes v5 will
have. Independently useful: it removes `skip_authorization` from v4 today.

**Phase 2 — v5 serializers built on the DSL from day one,** with enforcement on
(raise on undeclared). New code, so no migration cost — this is the cheapest moment
to make it mandatory, and the reason to settle the design *before* v5 endpoints get
written.

**Phase 3 — collapse the forks.** Delete `app/policies/api/` and every `*_in_v4?`.
Until v3/v4 are actually deprecated, redefine the `Api::` policies as thin
delegations to the canonical ones so there's a single source of truth *during* the
overlap rather than only after it.

**Phase 4 — chip away at the 151 `organizer_signed_in?` call sites,** replacing
them with policy predicates. Long tail, no deadline, but every one converted is one
less thing the API has to reimplement.

## Open Questions

1. **Is the web/API split on `account_number` deliberate?** The web reveals the
   full number to a manager; v4 ships four digits. Initial read is that it's
   accidental. If so, unify on the last-4 and drop `:account_number` from the
   list. If not, write down why — nothing records it today. Same question, more
   clearly accidental, for `bank_name`.
2. **How do field declarations interact with `expand`?** `expand=balance_cents`
   controls *cost*; policy controls *permission*. Keep them orthogonal — a field
   must pass both. `_event.json.jbuilder:37` already ANDs them
   (`policy(event).account_number? && expand?(:account_number)`).
3. **Do we generate v5 field docs from `declared_fields`?** Attractive — the
   policy becomes the single source for both enforcement and the docs table, and
   the docs can't go stale.
4. **`Ledger::Item` field-gating.** The new engine changes the shape
   (`app/models/ledger/item.rb`), and `Ledger::Query` still carries a
   `# TODO: handle authorization` (`app/models/ledger/query.rb:38`). Client-supplied
   query hashes filtering on fields the viewer can't *see* is a live inference
   channel — worth resolving alongside this.
5. **HCB codes as dummy secondary IDs.** Unresolved elsewhere, but relevant here:
   if `hcb_code` survives as a legacy ID it becomes a field like any other and
   needs a visibility declaration.
