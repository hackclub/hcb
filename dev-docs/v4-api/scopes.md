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

## Admin Scopes

See [Admin Access in standards.md](./standards.md#admin-access) for the full treatment.