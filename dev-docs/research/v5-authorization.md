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
- [Why `permitted_attributes` Isn't The Answer](#why-permitted_attributes-isnt-the-answer)
- [Proposal](#proposal)
  - [1. One principal, not one policy per surface](#1-one-principal-not-one-policy-per-surface)
  - [2. Field visibility as declared policy predicates](#2-field-visibility-as-declared-policy-predicates)
  - [3. Enforcement: the serializer cannot emit an undeclared field](#3-enforcement-the-serializer-cannot-emit-an-undeclared-field)
  - [4. Index routes: actually use `policy_scope`](#4-index-routes-actually-use-policy_scope)
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

## Why `permitted_attributes` Isn't The Answer

The instinct is right — a policy-owned declaration of which fields a viewer may
see is exactly what's needed. Pundit's specific `permitted_attributes` API is the
wrong carrier for it, for four reasons.

**1. It already means something else here, for input.** Pundit's
`permitted_attributes` is a strong-parameters helper: the policy returns a symbol
list, the controller feeds it to `params.permit` for mass assignment. We use it
that way today:

```ruby
# app/controllers/sponsors_controller.rb:69
params.require(:sponsor).permit(policy(Sponsor).permitted_attributes)
```

Overloading one method to mean both "what may be written" and "what may be read"
guarantees confusion, and the two lists genuinely differ (a manager may *read* an
ACH's routing number long after it's immutable).

**2. It's column-shaped; our fields are not.** `permitted_attributes` returns
model attribute names. Look at what v5 actually needs to gate:

| Field | Why a column list can't express it |
|---|---|
| `account_number_last4` | derived — `account_number.slice(-4, 4)`, no such column |
| TIN last-4 | not in our DB at all; fetched from TaxBandits |
| `avatar` | computed URL from `profile_picture_for(user, size)` |
| `name` | `user.initial_name`, not `user.name` |
| `balance_cents` | an aggregate over the ledger |
| `shipping_address` | a nested block sourced from `stripe_cards.physical.last` |
| `card_charge` / `donation` / `check` | polymorphic subtrees on a transaction |

A field name in an API response is a **key in the output contract**, not a model
attribute. Any design that conflates the two fails on the first derived field —
and derived fields are the majority of the interesting cases.

**3. It has no notion of *why* a field is visible.** The ERB side doesn't want a
filtered hash; it wants to know whether to render a table row and a
copy-to-clipboard button. It needs the predicate, not the list.

**4. It's per-record, but transparency is per-viewer-relationship.** The same ACH
transfer shows different fields to an anonymous visitor on a transparent org, a
reader, a manager, and an admin. That's a lattice, and it maps cleanly onto the
private predicates policies *already* define (`reader?`, `member?`, `manager?`,
`admin?`, `is_public` — `app/policies/event_policy.rb:311-363`).

So: keep the concept, drop the API.

---

## Proposal

Four changes. (1) and (4) are independently valuable and can land before v5 exists.

### 1. One principal, not one policy per surface

`show_in_v4?` exists because v4 didn't want anonymous transparency. But that isn't
a different *rule*, it's a different *actor*. We already have the right shape for
this — `ApiAdminContext` (`app/models/api_admin_context.rb`) is a principal object
that ANDs `admin?`/`auditor?` with token scopes so policies don't have to know
about tokens. Generalize it:

```ruby
class Principal
  # delegate_missing_to :@user, as ApiAdminContext already does
  attr_reader :user, :token, :surface   # :web | :api
end
```

- Web: `Principal.new(user: current_user, token: nil, surface: :web)`
- v5: `Principal.new(user: current_user, token: current_token, surface: :api)`
  — anonymous requests get `user: nil`, which is exactly what v3 passes today.

Then **delete every `*_in_v4?` method and the whole `app/policies/api/` namespace.**
`EventPolicy#show?` — `is_public || auditor_or_reader?` — becomes the single answer
for web, v3, and v5 alike.

> **The objection, and the answer.** "But then an OAuth app granted
> `organizations:read` for one user could walk every transparent org." True, and
> that's a real concern — but it is a **token** concern, not a **user** concern, and
> we already have a layer for it. `dev-docs/v4-api/scopes.md` states the split
> explicitly: *"Scopes restrict tokens; policies restrict users."* The fix is a
> `transparency:read` scope, not a forked policy method. Once that's clear, the
> `_in_v4?` fork has no reason to exist — it was scope enforcement smuggled into
> the policy layer.

### 2. Field visibility as declared policy predicates

Add a small class-level DSL to `ApplicationPolicy`. It binds **output field names**
(JSON keys, not columns) to **predicates the policy already has**:

```ruby
class AchTransferPolicy < ApplicationPolicy
  field :recipient_name, :recipient_email, :bank_name, :payment_for, :sender,
        visible_to: :show?

  field :account_number_last4, :routing_number,
        visible_to: :view_account_routing_numbers?

  def show?
    is_public || auditor_or_reader?     # transparency restored, no fork
  end

  def view_account_routing_numbers?
    admin_or_manager?                   # unchanged, already correct
  end
end
```

This gives three things off one declaration:

```ruby
policy.visible?(:routing_number)  # => predicate, for ERB *and* jbuilder
policy.visible_fields             # => Set, for the serializer + docs generation
AchTransferPolicy.declared_fields # => Set, for the drift spec
```

Notes on the design:

- **Field names are contract names, not attributes.** `field :account_number_last4`
  declares the JSON key; the serializer still decides it's `slice(-4, 4)`. This is
  the property that makes derived fields, TaxBandits-fetched values, and nested
  blocks all expressible.
- **Nested blocks are declared by their root key.** `field :shipping_address,
  visible_to: :view_own_pii?` gates the whole subtree; anything genuinely finer
  gets its own nested policy.
- **Polymorphic subtrees delegate.** `json.card_charge` is gated by
  `CardChargePolicy`, not by a field on the transaction — which is roughly what
  `_transaction.json.jbuilder:37` does today, just made explicit.
- **The `expand_pii` logic moves into policies.** `visible_to: :view_own_pii?`,
  where that predicate is `record == user || (principal.admin? && token has pii)`.
  That makes it reachable from ERB, which it currently isn't.

### 3. Enforcement: the serializer cannot emit an undeclared field

This is the part that actually delivers "web and v5 can't diverge". Declaring
fields is worthless if the serializer can still ignore the declaration.

Give v5 a jbuilder wrapper that consults the policy:

```ruby
# in the v5 serializer helper
def field(json, record, key, &block)
  policy = policy_for(record)
  unless policy.class.declares_field?(key)
    raise UndeclaredFieldError, "#{policy.class}: #{key} is not declared" if Rails.env.local?
    return                                    # fail closed in production
  end
  return unless policy.visible?(key)
  json.set!(key, block ? block.call : record.public_send(key))
end
```

- **In dev/test, adding a `json.foo` without a `field :foo` raises.** You cannot
  ship an unauthorized field.
- **In production, it fails closed** — omitted, never leaked.

Back that with two specs:

1. **Field-drift spec** — render every v5 partial with a stub collector, diff the
   emitted keys against `Policy.declared_fields`, fail on either direction (an
   undeclared emission *or* a declared-but-dead field).
2. **No-fork spec** — assert `app/policies/api/` is empty and that no policy method
   matches `/_in_v\d\?$/`. Cheap, and it's the thing that stops this document's
   problem from recurring.

**On the ERB side, be honest about the scope.** ERB has no mechanical output
contract, so there's nothing to auto-filter — and that's fine. ERB doesn't need
filtering; it needs *the same predicate*. `visible?(ach_transfer, :routing_number)`
in a view is the same call the serializer makes, resolved by the same policy object.
That's what makes drift impossible: not that both sides are filtered the same way,
but that **both sides read one declaration.** The 12 existing inline checks in
jbuilder and their ERB twins become instances of one named mechanism.

### 4. Index routes: actually use `policy_scope`

Replace all three current approaches with the one Pundit ships:

```ruby
# v5 base controller
after_action :verify_authorized
after_action :verify_policy_scoped, only: :index
```

Every index becomes `policy_scope(Model)` or `policy_scope(@event.tags)`, and each
policy grows a real `Scope#resolve`. **`skip_authorization` in an index action
becomes a lint failure.**

This also solves transparency for index routes for free — the anonymous branch of a
`Scope` is exactly the `Event.transparent` filter v3 hardcodes:

```ruby
class EventPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all                      if user&.auditor?
      return scope.transparent.not_hidden   if user.nil?
      scope.transparent.not_hidden.or(scope.where(id: user.readable_events.select(:id)))
    end
  end
end
```

**Performance caveat, and it's a real one.** `Scope#resolve` must return SQL, but
our role checks are Ruby that walks `ancestor_organizer_positions`, and event
visibility already involves a recursive CTE (`app/models/event.rb:236-247`).
Naïvely translating predicates into scopes will produce N+1s or wrong answers.
Plan for a `Event.visible_to(user)` SQL scope on the model, called from
`Scope#resolve`, with a spec asserting that for a sample of records
`Model.visible_to(u).include?(r) == policy(u, r).show?`. That equivalence test is
what keeps the Ruby and SQL paths honest.

---

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

**Phase 0 — pilot, one object end to end.** Build `Principal` + the `field` DSL,
apply to `AchTransferPolicy` only. It's the ideal pilot: it's the motivating
example, it already has `view_account_routing_numbers?`, and it has all three
consumers (ERB at `_ach_transfer.html.erb:66`, jbuilder at
`_ach_transfer.json.jbuilder:10`, Grape entity). Prove the same declaration drives
all three. No behavior change.

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

1. **Should `field` be mandatory or advisory in v5?** Recommendation: mandatory,
   enforced by the raise in section 3. Advisory decays to the status quo.
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
