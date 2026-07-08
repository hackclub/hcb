# v4 API Standards

This document defines the conventions and standards for the HCB v4 API. All new endpoints **must** follow these guidelines. When modifying existing endpoints, bring them into compliance where practical.

---

## Table of Contents

- [Basics](#basics)
- [Authentication](#authentication)
- [Object Shape](#object-shape)
- [IDs & Object References](#ids--object-references)
- [Object Arrays](#object-arrays)
- [Shallow Routing](#shallow-routing)
- [Pagination](#pagination)
- [Expanding Related Objects](#expanding-related-objects)
- [Partials & Reuse](#partials--reuse)
- [Error Responses](#error-responses)
- [Admin Access](#admin-access)
- [Naming Conventions](#naming-conventions)
- [Rate Limits](#rate-limits)
- [Request Size & Timeouts](#request-size--timeouts)

---

## Basics

- **Requests and responses use JSON by default.** Send `Content-Type: application/json` and expect `application/json` back.
- Two exceptions: **file uploads** (e.g. `POST /api/v4/receipts`) use `multipart/form-data`, and the **OAuth token endpoint** accepts `application/x-www-form-urlencoded`. There is no XML support.

---

## Authentication

The v4 API uses **OAuth 2.0** (via Doorkeeper). Every request must include a valid Bearer token in the `Authorization` header:

```
Authorization: Bearer hcb_<token>
```

### Creating an OAuth Application

There are two ways to register an app. The examples below use the local dev host `localhost:3000`; on **production, use `https://hcb.hackclub.com`** for the same `/api/v4/oauth/...` endpoints and the application UI at `https://hcb.hackclub.com/api/v4/oauth/applications`, with a real `redirect_uri`.

> To use the granular v4 scopes (e.g. `restricted receipts:write ledgers:read receipts:read`), register the application with **those** scopes instead of `read write`, and request the same strings in the authorize step. See [Requesting Scopes on a Token](./scopes.md#requesting-scopes-on-a-token).

**Option A — Web UI**

1. Go to [localhost:3000/api/v4/oauth/applications](http://localhost:3000/api/v4/oauth/applications) and press "New Application".
2. Set the name to anything, the redirect URI to `http://localhost:3000/`, and scopes to `read write`. Leave "Confidential" checked (see [oauth.net/2/client-types](https://oauth.net/2/client-types) for context).
3. Press "Submit", save the `client_id` and `client_secret` shown, then press "Authorize".

**Option B — Rails console**

```ruby
app = Doorkeeper::Application.create(
  name: "tester",
  redirect_uri: "http://localhost:3000/",
  scopes: ["read", "write"],
  confidential: false
)
```

Save the `uid` and `secret` from the output.

### Getting an Access Token (Authorization Code flow)

1. Direct the user to:
   ```
   /api/v4/oauth/authorize?client_id=<UID>&redirect_uri=http://localhost:3000/&response_type=code&scope=read%20write
   ```
2. After the user approves, copy the `code` from the redirect URL.
3. Exchange it for a token:
   ```
   POST /api/v4/oauth/token
   Content-Type: application/x-www-form-urlencoded

   grant_type=authorization_code
   code=<CODE>
   client_id=<UID>
   client_secret=<SECRET>
   redirect_uri=http://localhost:3000/
   ```

HCB also supports the `device_code` grant type for CLI tools and devices without a browser (useful for a headless agent). See the [doorkeeper-device_authorization_grant docs](https://github.com/exop-group/doorkeeper-device_authorization_grant#usage). HCB mounts these endpoints under `api/v4/oauth` instead of the default `oauth` — that is a URL **path prefix**, not an OAuth access scope, so don't add `api/v4/oauth` to your requested `scope=`.

### Token Expiry & Refresh

Access tokens expire after **2 hours**. Every token response includes a `refresh_token` that can be used to get a new access token without re-authorizing the user:

```
POST /api/v4/oauth/token
Content-Type: application/json

{
  "grant_type": "refresh_token",
  "refresh_token": "<refresh_token>",
  "client_id": "<client_id>",
  "client_secret": "<client_secret>"
}
```

Your application **must** handle token refresh. Requests made with an expired token will receive a `401 Unauthorized`.

---

## Object Shape

Every top-level API object **must** include the following fields:

| Field        | Type     | Description                                      |
|--------------|----------|--------------------------------------------------|
| `id`         | `string` | The public ID of the object (e.g. `txn_abc123`). |
| `object`     | `string` | A machine-readable type label (e.g. `transaction`, `ach_transfer`). Derived from the model name. |
| `created_at` | `string` | ISO 8601 timestamp of when the object was created. |

### The `object_shape` Helper

Use the `object_shape` helper to set these three fields consistently across all partials:

```ruby
def object_shape(json, object, &block)
  json.id object.public_id
  json.object object.model_name.element
  block.call
  json.created_at object.created_at
end
```

This helper derives the `object` field automatically from the model's class name (e.g. an `AchTransfer` record produces `"ach_transfer"`), so you never need to hardcode it.

#### Object Name Overrides

Some internal model names don't match their public API name. The helper consults a centralized override list before falling back to the class name:

| Model   | API `object` value |
|---------|--------------------|
| `Event` | `"organization"`   |

If you need to add a new override, update the override list in the `object_shape` helper. **Do not** pass the name manually at the call site.

Every object's partial should wrap all fields in a call to `object_shape`:

```ruby
# app/views/api/v4/ach_transfers/_ach_transfer.json.jbuilder
# locals: (ach_transfer:)

object_shape(json, ach_transfer) do
  json.recipient_name ach_transfer.recipient_name
  json.amount_cents ach_transfer.amount
  # ...
end
```

This produces:

```json
{
  "id": "ach_x9f3k",
  "object": "ach_transfer",
  "recipient_name": "Sal Khan",
  "amount_cents": 4500,
  "created_at": "2025-03-15T12:00:00Z"
}
```

---

## IDs & Object References

- Always use **public IDs** (the `public_id` from `PublicIdentifiable`) in API responses. Never expose internal database IDs.
- When creating a new public ID prefix it should be 3 letters.
- When referencing a related object by ID only (not expanded), use the pattern `<relation>_id`:

```json
{
  "id": "ach_x9f3k",
  "object": "ach_transfer",
  "organization_id": "org_h1izp",
  "sender_id": "usr_a8b2c"
}
```

- When a related object is **expanded**, replace the `_id` field with the full object under the relation name:

```json
{
  "id": "ach_x9f3k",
  "object": "ach_transfer",
  "organization": {
    "id": "org_h1izp",
    "object": "organization",
    "name": "Hack Club HQ"
  }
}
```

---

## Object Arrays

**Never include an array of API objects inside another object's response.** If a resource has a list of related objects, that list belongs at its own index endpoint — not embedded in the parent.

For example, a `user` object must never include a list of organizations. The caller should instead request:

```
GET /api/v4/organizations?user_id=usr_abc123
```

This keeps payloads predictable, makes pagination possible, and avoids over-fetching.

The one exception is arrays that do **not** contain API objects (e.g. an array of plain strings or numbers). This should be extremely rare — if you find yourself reaching for it, it is almost always a sign that the data belongs in a separate endpoint.

---

## Shallow Routing

All endpoints **must** use shallow routing. Every resource should be accessible at its own top-level path. Parent context is passed as a query parameter when needed, not embedded in the URL hierarchy.

### Good

```
GET    /api/v4/transactions/:id                          # show
PATCH  /api/v4/transactions/:id                          # update
GET    /api/v4/transactions?organization_id=org_h1izp    # list scoped to org
POST   /api/v4/ach_transfers                             # create within org
       body: { organization_id: org_h1izp }
GET    /api/v4/cards/:id                                 # show
GET    /api/v4/receipts?transaction_id=txn_abc           # list scoped to transaction
```

### Bad

```
POST   /api/v4/organizations/:org_id/ach_transfers
GET    /api/v4/organizations/:org_id/transactions
GET    /api/v4/organizations/:org_id/transactions/:txn_id/receipts/:receipt_id
GET    /api/v4/organizations/:org_id/cards/:card_id/transactions/:txn_id
```

**Rule of thumb:** If a resource has its own ID, it gets its own top-level route. Use query parameters (e.g. `?organization_id=`, `?transaction_id=`) to scope listings and provide parent context for creation. Never nest resources inside other resources in the URL path.

---

## Pagination

All list endpoints **must** return paginated responses using cursor-based pagination.

### Response Envelope

```json
{
  "total_count": 142,
  "has_more": true,
  "data": [
    { "id": "txn_abc", "object": "transaction", "..." : "..." },
    { "id": "txn_def", "object": "transaction", "..." : "..." }
  ]
}
```

| Field         | Type      | Description                                              |
|---------------|-----------|----------------------------------------------------------|
| `total_count` | `integer` | Total number of results matching the query.              |
| `has_more`    | `boolean` | Whether more results exist beyond this page.             |
| `data`        | `array`   | The page of results.                                     |

### Query Parameters

| Parameter | Default | Description                                                        |
|-----------|---------|--------------------------------------------------------------------|
| `limit`   | `25`    | Number of results to return (max `100`).                           |
| `after`   | —       | Cursor: return results after this object's `id` (exclusive).       |

Example request:

```
GET /api/v4/organizations/org_h1izp/transactions?limit=10&after=txn_abc
```

### Implementation Notes

- Cursors should be the `public_id` of the last item on the current page.

---

## Expanding Related Objects

To reduce payload size and unnecessary database work, related objects are **not** included by default. Developers opt in using the `expand` query parameter. The expand query parameter takes in the field name as the `key` not the type of the association.

```
GET /api/v4/cards/crd_x9f3k?expand=user,organization
```

### How It Works

- Without expansion, a related object appears as an ID string:
  ```json
  { "organization_id": "org_h1izp" }
  ```
  - An exception to this would be object arrays as those can't be represented as an ID string
- With `?expand=organization`, the full object replaces the ID field:
  ```json
  {
    "organization": {
      "id": "org_h1izp",
      "object": "organization",
      "name": "Hack Club HQ"
    }
  }
  ``` 

### Implementation

Use `expand_association` in jbuilder partials for any field that references a related object by ID. It handles both cases automatically:

```ruby
expand_association(json, :organization, ach_transfer.event,
                   partial: "api/v4/events/event", as: :event)

expand_association(json, :sender, ach_transfer.creator,
                   partial: "api/v4/users/user", as: :user)
```

- When `:organization` is **not** in `expand`, renders `"organization_id": "org_h1izp"`.
- When `:organization` **is** in `expand`, renders the full object under `"organization": { ... }`.
- If the record is `nil`, renders `null` in both cases.
- Associations must have a `public_id` method.

For non-association expansions — computed fields, structured data, or arrays — use `expand?` directly since there is no `_id` fallback:

```ruby
json.balance_cents event.balance_available if expand?(:balance_cents)

if expand?(:shipping_address)
  json.shipping_address do
    # ...
  end
end
```

### Guidelines

- Use `expand_association` for any field that is a reference to another API object.
- Use `expand?(:symbol)` directly for computed fields, structured data, or arrays that have no `_id` equivalent.
- Certain contexts auto-expand relevant objects for convenience (e.g. listing cards under an organization auto-expands `user`). Document these per-endpoint.
- Avoid deep expansion chains (e.g. `expand=organization.users.cards`). One level is sufficient.
- Each endpoint should document which fields are expandable.

### Currently Supported Expansions

Check each endpoint's documentation for its supported expansions. Common ones include:

| Expansion           | Available On                             |
|---------------------|------------------------------------------|
| `organization`      | transactions, cards, card grants         |
| `user`              | cards, card grants                       |
| `balance_cents`     | organizations                            |
| `account_number`    | organizations (requires permission)      |
| `users`             | organizations                            |
| `total_spent_cents` | cards                                    |

---

## Partials & Reuse

Every API-representable model **must** have a single canonical jbuilder partial (e.g. `_ach_transfer.json.jbuilder`). All endpoints that render that object must use the partial.

### Why?

- A single source of truth for each object's shape.
- Developers rely on the same fields appearing whether the object is returned from a show, list, or nested context.
- Reduces copy-paste bugs.

### Rules

1. **One partial per model.** Located at `app/views/api/v4/<resource>/_<resource>.json.jbuilder`.
2. **Always declare strict locals.** Every partial must begin with a strict locals magic comment. This makes the partial's dependencies explicit and raises an error if unexpected variables are passed. See the [Rails 7.1 strict locals guide](https://blog.appsignal.com/2024/09/11/ruby-on-rails-7-1-partial-strict-locals-and-their-gotchas.html) for details.
   ```ruby
   # locals: (ach_transfer:)
   ```
3. **Nest, don't duplicate.** If a transaction includes an ACH transfer, render `partial: "api/v4/transactions/ach_transfer"`.
4. **Show endpoints are thin.** A `show.json.jbuilder` should be essentially:
   ```ruby
   json.partial! @ach_transfer
   ```
5. **List endpoints are wrapped in pagination**, then render partials for each item.

### Example

```ruby
# app/views/api/v4/ach_transfers/_ach_transfer.json.jbuilder
# locals: (ach_transfer:)

object_shape(json, ach_transfer) do
  json.recipient_name ach_transfer.recipient_name
  json.recipient_email ach_transfer.recipient_email
  json.amount_cents ach_transfer.amount
  json.status ach_transfer.aasm_state

  if expand?(:organization)
    json.organization ach_transfer.event, partial: "api/v4/events/event", as: :event
  else
    json.organization_id ach_transfer.event.public_id
  end
  
  if expand?(:sender)
    json.sender do
      if ach_transfer.creator.present?
        json.partial! "api/v4/users/user", user: ach_transfer.creator
      else
        json.nil!
      end
    end
  else
    json.sender_id ach_transfer.creator&.public_id
  end
end
```

---

## Error Responses

Errors follow a consistent shape:

```json
{
  "error": "invalid_operation",
  "messages": [
    "You don't have enough money to send this transfer! Your balance is $42.00."
  ]
}
```

| Field      | Type            | Description                                          |
|------------|-----------------|------------------------------------------------------|
| `error`    | `string`        | A machine-readable error code.                       |
| `messages` | `array<string>` | One or more human-readable descriptions.             |

### Standard Error Codes

HTTP status codes should use Rails' symbolic names (e.g. `render json: ..., status: :not_found`). See the [Rails HTTP status code reference](https://kapeli.com/cheat_sheets/HTTP_Status_Codes_Rails.docset/Contents/Resources/Documents/index) for the full list.

| Code                 | HTTP Status | Meaning                                              |
|----------------------|-------------|------------------------------------------------------|
| `bad_request`        | `400`       | Request is well-formed but violates a business rule. |
| `unauthorized`       | `401`       | Missing or invalid API token.                        |
| `forbidden`          | `403`       | Token is valid but lacks permission.                 |
| `not_found`          | `404`       | Resource does not exist.                             |

For validation errors, they should ideally be automatically handled by the application level error handling concern which exposes validation error messages. 

---

## Admin Access

By default, the API behaves as if admin users have "pretend not to be an admin" enabled. This applies even HCB staff with admin privileges will only see what a regular user sees. Admin capabilities are **never active by default**.

To gain admin permissions via the API, the token must explicitly carry an admin scope:

| Scope          | Description                                                          |
|----------------|----------------------------------------------------------------------|
| `admin:read`   | Grants read-only access to admin-level data (e.g. all organizations, internal fields). |
| `admin:write`  | Grants the ability to perform write actions reserved for admins.     |

`admin:write` does **not** imply `admin:read` — both scopes must be granted independently if both are needed.

Admin access can also be narrowed to one resource type instead of the blanket scopes above - either by requesting a **resource-limited admin scope** (`admin.<resource>:<level>`, e.g. `admin.organizations:read`) through the normal OAuth flow, or by issuing the token a **resource-scoped admin grant** server-side, which can additionally narrow down to specific organizations, users, or individual records. Both forms are honored everywhere the blanket scopes are, including inside Pundit policies. See [Admin Scopes](./scopes.md#admin-scopes) for the full treatment and [Object Scopes](./scopes.md#object-scopes) for the grant mechanism.

### Implementation Notes

- Always check for the admin scope explicitly. Do not fall back to checking if the authenticated user is an admin.
- Endpoints that expose admin-only data or actions must document which scope they require.
- You must have both the API scope and the access_level to gain access

---

## Naming Conventions

| Concept                  | Convention                                      | Example                          |
|--------------------------|-------------------------------------------------|----------------------------------|
| Money amounts            | Suffix with `_cents`, always integers            | `amount_cents`, `balance_cents` |
| Booleans                 | Use natural predicates, no `is_` prefix in JSON  | `pending`, `declined`, `transparent` |
| Timestamps               | Suffix with `_at`, ISO 8601 format               | `created_at`, `approved_at`     |
| Dates (no time)          | Suffix with `_on` or `_date`                     | `scheduled_on`, `due_date`      |
| Related object IDs       | Suffix with `_id`                                | `organization_id`, `sender_id`  |
| Enum/status fields       | Lowercase snake_case strings                     | `"pending"`, `"in_transit"`     |
| Collections in URL paths | Plural nouns                                     | `/transactions`, `/cards`       |

### Amounts

All monetary values are represented in **cents** (the smallest currency unit) as integers. Never use floats for money.

```json
{
  "amount_cents": 4200,
  "balance_cents": 150000
}
```

---

## Rate Limits

Requests are throttled at **1,000 requests per 5 minutes per IP address**. Requests that exceed this limit receive a `429 Too Many Requests` response.

---

## Request Size & Timeouts

Every request is bound by a **30-second server timeout**. A call that runs longer is terminated, so keep each request small and page through results instead of asking for everything at once.

- **Paginate listings.** For cursor-paginated list endpoints, the `limit` query param sets the page size: it **defaults to 25** and is **capped at 100** (a larger value returns `400 invalid_operation`). Follow the `after` cursor to page (see [Pagination](#pagination)).
- **Prefer smaller pages.** Request modest pages such as `?limit=25` and follow the cursor, rather than pushing `limit` to 100 on a large dataset. Smaller pages return faster and stay well under the 30s ceiling.

  ```
  GET /api/v4/organizations/org_h1izp/transactions?limit=25
  # then pass the last item's id back as ?after=txn_… for the next page
  ```
- **Large uploads count too.** A `multipart/form-data` upload (e.g. `POST /api/v4/receipts`, files up to 50 MB) is also subject to the 30s timeout; a large file over a slow link can approach it. If an upload times out you cannot tell from the response whether it landed.

---

## Checklist for New Endpoints

Before opening a PR that adds or modifies a V4 API endpoint, verify:

- [ ] Every returned object has `id`, `object`, and `created_at` (via `object_shape`)
- [ ] Public IDs are used (never raw database IDs)
- [ ] Routing is shallow (max one level of nesting)
- [ ] List endpoints return the pagination envelope (`total_count`, `has_more`, `data`)
- [ ] No arrays of API objects are embedded in a response (use a scoped index endpoint instead)
- [ ] Association fields use `expand_association` (never a bare `if expand?` with a manual `_id` fallback)
- [ ] Non-association expansions (computed fields, arrays) use `expand?` directly
- [ ] Related objects use `expand` and are not auto-included without reason
- [ ] The model's canonical partial is used (not inlined fields)
- [ ] Every partial declares strict locals (`# locals: (<resource>:)`)
- [ ] Error responses use the standard shape
- [ ] Money is in `_cents` as integers
- [ ] Endpoint is authorized via Pundit policy
- [ ] Admin-only behavior requires an explicit `admin:read` or `admin:write` scope (never inferred from user role)