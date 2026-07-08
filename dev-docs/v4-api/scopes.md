# v4 API Scopes

This document explains how OAuth 2.0 scopes work in the HCB v4 API: the permission model, how scopes are enforced, the current scope inventory, and how to add a new one. 

> Read this alongside [`standards.md`](./standards.md), which covers the broader v4 API conventions (authentication, object shape, pagination, etc.). This file drills into the **scope** layer specifically.

---

## Table of Contents

- [Overview](#overview)
- [Two Layers of Authorization](#two-layers-of-authorization)
- [The `restricted` Scope & Gradual Rollout](#the-restricted-scope--gradual-rollout)
- [Declaring Scope Requirements](#declaring-scope-requirements)
- [Scope Naming Conventions](#scope-naming-conventions)
- [Adding a New Scope](#adding-a-new-scope)
- [Field Scopes](#field-scopes)
- [Object Scopes](#object-scopes)
- [Admin Scopes](#admin-scopes)

---

## Overview

The v4 API uses **OAuth 2.0 scopes** (via [Doorkeeper](https://doorkeeper.gitbook.io/guides/ruby-on-rails/scopes)) to limit what a given access token is allowed to do. A scope is a string (e.g. `ledgers:read`, `receipts:write`) attached to a token when an OAuth application is authorized.

Scopes let an application request **only the access it needs**. For example, a receipt-uploading integration can request `receipts:write` without gaining the ability to read transactions or move money.

Scopes are stored on the access token. They are checked **per controller action** at request time.

---

## Two Layers of Authorization

Every v4 API request passes through **two independent checks**. Both must pass.

1. **Pundit policy authorization** (`authorize @record`) — answers *"is this user allowed to touch this record?"* Based on the authenticated user's role/relationship to the resource. This always runs (`after_action :verify_authorized`).
2. **OAuth scope enforcement** (`require_oauth2_scope`) — answers *"is this token permitted to perform this kind of action?"* Based on the scopes granted to the token, independent of who the user is.

A token can fail the scope check even when the user would otherwise be authorized, and vice versa. **Scopes restrict tokens; policies restrict users.**

Everything in this document ultimately answers one of three questions about a request:

| Question | Mechanism |
|---|---|
| Can this token call this **action**? | `require_oauth2_scope` (this section and the next few) |
| Can this token see this **field**? | Inline capability check in the jbuilder view - see [Field Scopes](#field-scopes) |
| Which **objects** can this token touch within an action it's otherwise allowed to call? | Pundit, narrowed by the token's own grants - see [Object Scopes](#object-scopes) |

The first two share the same scope-string vocabulary and are checked the same way (a flat membership test against the token's granted scopes). The third is a Pundit-layer concern: it never changes what an action can do, only which rows it can do it to, and it applies automatically wherever `authorize`/`policy_scope` already run - no separate opt-in.

---

## The `restricted` Scope & Gradual Rollout

Per-action scope enforcement is **opt-in per token**, gated behind a special scope named `restricted`. This exists so the granular scope system can roll out without breaking existing OAuth apps that were created before scopes existed.

| Token state | Behavior |
|-------------|----------|
| Token **does not** include `restricted` | All per-action scope checks are **skipped**. The token can reach any action (legacy behavior). Only Pundit policies apply. |
| Token **includes** `restricted` | Per-action scope checks are **enforced**. The token can *only* reach actions that have an explicit `require_oauth2_scope` declaration, **and** only if it holds every required scope for that action. |

Key consequences for a `restricted` token:

- An action with **no** `require_oauth2_scope` declaration is **forbidden** — a restricted token is deny-by-default.
- An action **with** a declaration requires the token to carry **all** declared scopes for that action.

> This means new granular scopes are only meaningful for tokens that also carry `restricted`. The intent is to eventually require `restricted` on all tokens, at which point the gate is removed and scopes are universally enforced.

---

## Requesting Scopes on a Token

Scopes are granted to a token through the standard OAuth flow (see [Authentication in standards.md](./standards.md#authentication)); they aren't attached automatically. Two things must line up:

1. **The OAuth application must be registered with the scopes.** Set the application's `scopes` to include every scope it will request (e.g. `restricted receipts:write ledgers:read receipts:read`). The server does not restrict applications to a fixed list: `enforce_configured_scopes` is off and `optional_scopes` lists only `read` / `write` / `admin:read` / `admin:write`, so the granular scopes above can be registered freely even though they aren't in that list.
2. **The token request must ask for them.** Pass the same space-separated strings in the `scope=` parameter of the `authorize` request (URL-encoded, so spaces become `%20`).

To get per-action enforcement (everything in this document), the requested scopes **must include `restricted`** alongside the granular ones. A token without `restricted` ignores every `require_oauth2_scope` declaration and falls back to legacy full access.

> The `api/v4/oauth` string in the OAuth endpoint paths (and in the device-grant docs) is the **route mount prefix** — the API and its OAuth endpoints live under `/api/v4` — **not** an OAuth access scope. Do not put `api/v4/oauth` in your `scope=` list.

---

### Registration (class-level)

`require_oauth2_scope` is a **class method** that records, per action, which scopes are required. It is typically called right after the action it guards:

```ruby
def self.require_oauth2_scope(required_scope, *actions)
  @oauth_requirements ||= Hash.new { |h, k| h[k] = [] }
  actions.each { |action| @oauth_requirements[action.to_sym] << required_scope }
end
```

- If the token isn't `restricted`, the check is a no-op.
- Otherwise the action must be declared **and** all its required scopes must be present.
- A failure raises `Pundit::NotAuthorizedError`, which the `ErrorHandling` concern renders as a `403 forbidden` (see [Error Responses in standards.md](./standards.md#error-responses)).

---

## Declaring Scope Requirements

Place a `require_oauth2_scope` call inside the controller, naming the scope and the action(s) it guards. Convention in this codebase is to put it **immediately after the action's method definition**.

```ruby
module Api
  module V4
    class TransactionsController < ApplicationController
      def index
        # ...
      end
      require_oauth2_scope "ledgers:read", :index

      def show
        # ...
      end
      require_oauth2_scope "ledgers:read", :show
    end
  end
end
```

You can guard multiple actions with one call:

```ruby
require_oauth2_scope "user_lookup", :show, :by_email
```

Multiple `require_oauth2_scope` calls for the same action **accumulate** — the token would then need all of them.

---

## Scope Naming Conventions

| Pattern | When to use | Examples |
|---------|-------------|----------|
| `<resource>:read` | Read-only access to a resource | `ledgers:read`, `organizations:read` |
| `<resource>:write` | Mutating a resource (create/update/destroy) | `receipts:write`, `card_grants:write` |
| `<capability>` | A narrow, single-purpose capability that doesn't map cleanly to read/write of one resource | `user_lookup`, `event_followers` |
| `admin:read` / `admin:write` | Admin-level data or actions (see [Admin Scopes](#admin-scopes)) | `admin:read`, `admin:write` |

Guidelines:

- `read` and `write` are **independent** — granting `:write` does not imply `:read`. Declare each where needed.
- Prefer the `<resource>:<action>` shape. Reach for a bare capability scope only when the access doesn't correspond to CRUD on a single resource.

---


## Adding a New Scope

To gate an action behind a new scope:

1. **Declare it in the controller** right after the action:
   ```ruby
   def create
     # ...
   end
   require_oauth2_scope "ach_transfers:write", :create
   ```
2. **Pick a name** following the [naming conventions](#scope-naming-conventions) — usually `<resource>:read` or `<resource>:write`.
5. **Test with a `restricted` token** — remember the scope only takes effect for tokens carrying `restricted`. A non-restricted token will bypass the check entirely.

---

## Field Scopes

Some fields inside a response should only be visible to certain tokens, without gating the whole action behind a scope. There's no separate DSL for this - it's the same capability check used for [admin scopes](#admin-scopes), just called inline from the jbuilder partial instead of a `before_action`:

```ruby
# app/views/api/v4/transactions/_transaction.json.jbuilder
if can_admin?(:read)
  json._debug do
    json.hcb_code hcb_code.hcb_code
  end
end
```

`can_admin?(level, resource:, record:)` is the same method `require_admin_scope!` uses at the action layer (see [Admin Scopes](#admin-scopes)) - pass `resource:` (and `record:`, once it's loaded) to narrow a field to a resource-scoped admin grant instead of the blanket scope. Prefer this over ad hoc `current_token.scopes.include?("...")` checks, which bypass the role check and the object-scope layer entirely.

---

## Object Scopes

Action and field scopes answer *"can this token do this kind of thing at all?"* Object scopes answer a different question: *"which specific rows can it do it to?"* This is enforced through Pundit, not through scope strings, and it composes with whatever action/field scopes already apply - it never grants access on its own for non-admin resources, only narrows it.

### How grants work

Object access is recorded as `ResourceGrant` rows (`resource_type`, `access_level`, and optionally a `scope_root_type`/`scope_root_id` pair). A grant's `owner` is polymorphic - either an `ApiToken` (a live grant enforced on that token) or a `Doorkeeper::Application` (a template copied onto every token minted for that application - see `after_successful_strategy_response` in `config/initializers/doorkeeper.rb`). A token with **no grants** for a given `(resource_type, access_level)` is fully unrestricted for that resource - this is the default for every token today, so adding this mechanism changes nothing until grants actually exist.

Two grant shapes:

| Shape | Meaning | Example |
|---|---|---|
| No scope root | Every record of this resource type (only meaningful for [admin grants](#admin-scopes) - a no-op otherwise, since a general capability scope already grants the whole type) | "all `comments`, read" |
| `scope_root_type` + `scope_root_id` set | Every record whose `#api_scope_roots` includes this root | "all `comments` under Event #42" |

`scope_root_type` is one of `User` or `Event` - a token can be scoped to a specific organization or to one user's own data. Most models resolve their roots automatically from their own `event_id`/`user_id` columns (see `ApiObjectScopable`); models that only reach their event/user through a polymorphic association (`Comment`, `Receipt`) declare `#api_scope_roots` explicitly.

### Enforcement

Object scopes are enforced automatically wherever the existing Pundit calls already run - there's no separate opt-in per controller:

- **Single-record actions** (`show`, `update`, `destroy`, ...) - `authorize @record` (overridden in `Api::V4::ApplicationController`) checks the token's grants for `@record.class.api_resource_type` right after Pundit's own check passes.
- **List actions** - `policy_scope(relation)` applies the same grants as a `.where(id: ...)` filter, via `ApplicationPolicy::Scope#resolve`. Policies with custom list logic (e.g. `CommentPolicy::Scope`) override `#visible_scope` instead of `#resolve`, so the grant filter still applies on top.

Read and write grants are independent, matching the `:read`/`:write` scope convention - the read access-level is derived from the HTTP verb (`GET`/`HEAD` = read, everything else = write).

### Declaring resource types

`api_resource_type` defaults to the pluralized class name (`Comment` → `"comments"`). Override it when a scope name spans multiple classes, matching whatever `require_oauth2_scope` already uses for that resource, e.g.:

```ruby
class Disbursement < ApplicationRecord
  api_resource_type "transfers"
  # ...
```

---

## Admin Scopes

See [Admin Access in standards.md](./standards.md#admin-access) for the full treatment.

A token can gain admin capability three ways, from broadest to narrowest:

1. **Blanket scope** - `admin:read` / `admin:write`. Full admin data access, no grants needed.
2. **Resource-scoped grant, no further narrowing** - an `ApiToken::ResourceGrant` with `resource_type: "comments"`, `access_level: "read"`, and neither a root nor a `resource_id`. This *is* the capability (unlike a general resource scope, there's no `comments:read`-style admin string to hold instead) - it replaces what would otherwise be a separate `admin.<resource>:<level>` scope string with the same [object-scope](#object-scopes) mechanism every other resource uses.
3. **Resource-scoped grant, narrowed to a root or record** - same as above, but also restricted to one organization/user/record via `scope_root_type`/`scope_root_id` or `resource_id`.

`can_admin?(level, resource:, record:)` and `require_admin_scope!(level, resource:, record:)` both accept `resource:` and `record:` to check either of the narrower forms. Pick the call site based on what's being gated:

| Gating... | Use |
|---|---|
| A whole action | `require_admin_scope!(level, resource:)` in a `before_action` |
| An extra field on an object already loaded | `can_admin?(level, resource:, record:)` in the jbuilder partial |

Only reach for a resource-scoped or object-scoped admin grant when an endpoint needs access narrower than "all admin data" - most endpoints should keep using the blanket scopes.