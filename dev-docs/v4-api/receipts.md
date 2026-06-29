# Managing Receipts with the v4 API

A guide to working with **receipts** in the HCB v4 API. It covers what a receipt is and the endpoints specific to receipts.

> This guide only documents what is **receipt-specific**. For everything general (authentication & OAuth, object shape (`id`/`object`/`created_at`), pagination, error responses, rate limits) see [`standards.md`](./standards.md). For the scope model, see [`scopes.md`](./scopes.md).

> **Handing this to an automated agent?** Also provide [`standards.md`](./standards.md) and [`scopes.md`](./scopes.md): this file does not restate how to authenticate or how the scope model works. At minimum the agent needs the base URL `https://hcb.hackclub.com/api/v4` and an `Authorization: Bearer hcb_<token>` header on every request.

---

## What Is a Receipt?

A **receipt** is an uploaded file (image, PDF, or CSV) documenting a transaction. It is a polymorphic attachment to a "receiptable" (usually a **transaction**, sometimes a reimbursement expense), or it can be **unattached**, sitting in the user's **Receipt Bin** awaiting a match. On upload, HCB asynchronously runs text extraction and suggests pairings between receipts in the Receipt Bin and transactions missing one.

| | |
|---|---|
| Public ID prefix | `rct` (e.g. `rct_a1b2c3`) |
| API `object` value | `receipt` |
| Accepted file types | `image/*`, `application/pdf`, `text/csv` |
| Max file size | 50 MB |

> A "transaction" in v4 is an `HcbCode`, public-ID prefix `txn`. `transaction_id` means a `txn_…` ID.

### The Receipt Bin

The **Receipt Bin** is a per-user holding area for receipts that aren't attached to any transaction yet. A user adds a receipt to their Receipt Bin when they have the document but haven't matched it to a transaction; HCB then suggests pairings so it can later be attached to the right one. Each user has their own Receipt Bin, and only that user can see or manage its contents. A receipt leaves the Receipt Bin once it's attached to a transaction. Via the API, a receipt lands in the Receipt Bin whenever it's uploaded **without** a `transaction_id`.

### The Receipt Object

Beyond the standard [`object_shape`](./standards.md#object-shape) fields (`id`, `object`, `created_at`):

| Field | Type | Description |
|-------|------|-------------|
| `url` | string | URL to the original uploaded file. |
| `preview_url` | string | URL to a generated image preview. |
| `filename` | string | Original filename. |
| `uploader` | object \| null | The `user` who uploaded it, or `null`. |

---

## Authentication & Scopes

OAuth Bearer tokens as described in [Authentication](./standards.md#authentication). Scopes are only enforced for tokens that also carry `restricted` (see [`scopes.md`](./scopes.md)). Always use a `restricted` token for least privilege: without `restricted`, none of the per-action scopes below are enforced and the token keeps full legacy access to the API.

| Action | Endpoint | Required scope |
|--------|----------|----------------|
| List receipts | `GET /api/v4/receipts` | `receipts:read` |
| Upload a receipt | `POST /api/v4/receipts` | `receipts:write` |
| Delete a receipt | `DELETE /api/v4/receipts/:id` | `receipts:write` |
| Mark a transaction no/lost receipt | `POST /api/v4/transactions/:id/mark_no_receipt` | `receipts:write` |
| Read transactions | `GET /api/v4/transactions/...` | `ledgers:read` |
| Find transactions missing a receipt | `GET /api/v4/transactions/missing_receipt` | `ledgers:read` |

> ⚠️ **`receipts:write` is broad.** A single `receipts:write` scope authorizes uploading **and** deleting receipts **and** marking transactions as no/lost receipt. The scope does not distinguish them. Keeping an agent from deleting or marking receipts is therefore a matter of agent instructions, not scope boundaries (see [Best Practices](#receipt-specific-best-practices)).

> A `restricted` token is **deny-by-default**: it can only reach actions that declare a scope it holds. Scopes gate the token; [Pundit policies](#delete-a-receipt) gate the user. Both must pass.

### Recommended scopes for a receipt agent

An automated agent that uploads receipts from a local directory and attaches them to the right transactions should request a **`restricted`** token carrying exactly:

- **`receipts:write`**: upload receipts and attach them to transactions.
- **`ledgers:read`**: read transactions, to find the ones missing a receipt and match each local file by amount, date, and merchant.
- **`receipts:read`**: list a transaction's existing receipts (and the Receipt Bin), so the agent can skip transactions that already have one instead of uploading duplicates.

This set is sufficient for the full workflow and grants **no ability to move money**: it carries no transfer, ACH, disbursement, or card-grant scopes, and a `restricted` token is denied by default on every action it does not hold a scope for.

## Workflow: Uploading a Directory of Receipts

A typical agent run:

1. **Authenticate.** Obtain a `restricted` OAuth token with `receipts:write`, `ledgers:read`, and `receipts:read` (see [Authentication](./standards.md#authentication) for the token flow). All requests go to `https://hcb.hackclub.com/api/v4` with an `Authorization: Bearer hcb_<token>` header.
2. **Discover transactions missing a receipt** via `GET /transactions/missing_receipt` (across all of the user's organizations in one call), or per organization via `GET /organizations/:id/transactions?filters[missing_receipts]=true`. Both require `ledgers:read`.
3. **Match each local file to a transaction** by amount, date, and merchant. Optionally call `GET /receipts?transaction_id=…` to confirm the transaction does not already have a receipt.
4. **Upload** with `POST /receipts`, always passing `transaction_id` (see [Create a Receipt](#create-a-receipt)).
5. **Skip what you cannot match.** Do not upload unmatched files to the Receipt Bin; flag them for a human.
6. **Never mark a transaction no/lost** without explicit per-transaction human authorization (see [Best Practices](#receipt-specific-best-practices)).

---

## Endpoints

All receipt routes are [shallow and top-level](./standards.md#shallow-routing).

### Create a Receipt

```
POST /api/v4/receipts
```

**Required scope:** `receipts:write`

This is the one endpoint that uses **`multipart/form-data`** rather than JSON, because a binary file can't be JSON-encoded.

| Param | Required | Description |
|-------|----------|-------------|
| `file` | yes | The receipt file (`image/*`, `application/pdf`, `text/csv`, ≤ 50 MB). |
| `transaction_id` | strongly recommended | A `txn_…` ID. Attaches the receipt to that transaction (user must pass `ReceiptablePolicy#upload?`, i.e. member+ on the org). **If omitted, the receipt goes to the [Receipt Bin](#the-receipt-bin)**, which can only be linked to a transaction via the [re-upload workaround](#linking-a-receipt-in-the-receipt-bin-to-a-transaction). |

```bash
# Attach to a transaction
curl -X POST https://hcb.hackclub.com/api/v4/receipts \
  -H "Authorization: Bearer hcb_<token>" \
  -F "transaction_id=txn_abc123" -F "file=@receipt.pdf"
```

Returns `201` with the [receipt object](#the-receipt-object). `upload_method` is set to `api` automatically; extraction and pairing run async after the response.

### List Receipts

```
GET /api/v4/receipts                          # the current user's Receipt Bin (unattached)
GET /api/v4/receipts?transaction_id=txn_abc   # receipts attached to a transaction
```

**Required scope:** `receipts:read`

Returns an array of [receipt objects](#the-receipt-object).

### Delete a Receipt

```
DELETE /api/v4/receipts/:id     # :id is an rct_… ID
```

**Required scope:** `receipts:write`

Governed by `ReceiptPolicy#destroy?`: receipts in the Receipt Bin can be deleted only by the uploader; transaction receipts require member+ on the org (and unlocked); reimbursement-expense receipts require the report owner or org manager (and unlocked); admins always. Returns `{ "message": "Receipt successfully deleted" }`.

### Find Transactions Missing a Receipt

```
GET /api/v4/transactions/missing_receipt
```

**Required scope:** `ledgers:read`

Returns the authenticated user's transactions (across their Stripe cards) still missing a receipt, newest first, [paginated](./standards.md#pagination).

### Mark a Transaction as No / Lost Receipt

```
POST /api/v4/transactions/:id/mark_no_receipt    # :id is a txn_… ID
```

**Required scope:** `receipts:write` · **Last resort, human-gated** (see [Best Practices](#receipt-specific-best-practices))

Removes the transaction from the missing-receipt list when no receipt exists. Requires `ReceiptablePolicy#mark_no_or_lost?` (member+). Returns `{ "message": "Transaction marked as no/lost receipt" }`.

---

## Linking a Receipt in the Receipt Bin to a Transaction

There is no single endpoint that moves a receipt out of the [Receipt Bin](#the-receipt-bin) onto a transaction. You can get the same result by re-uploading the file and deleting the original:

1. **List the Receipt Bin** with `GET /receipts` (`receipts:read`) and identify the receipt to move.
2. **Read its `url`** from the receipt object. This is a signed file URL, downloadable directly with **no `Authorization` header**.
3. **Download the file** from that `url`. Use the `filename` field for the local name.
4. **Upload it to the transaction** with `POST /receipts` (`receipts:write`), passing `transaction_id` and the downloaded `file`. Confirm a `201` before continuing.
5. **Delete the original** from the Receipt Bin with `DELETE /receipts/:id` (`receipts:write`). A receipt in the Receipt Bin can be deleted by its uploader, which is the token's own user.

**Scopes:** `receipts:read` + `receipts:write` (both in the [recommended agent set](#recommended-scopes-for-a-receipt-agent)); the download in step 3 needs no scope.

**Caveats:**

- **Order matters: delete only after a `201` upload.** If you delete first, or the upload fails, the file is gone.
- **Step 4 needs upload permission on the target organization** (`ReceiptablePolicy#upload?`, member+). If the user isn't a member of the transaction's org, the upload returns `403`; do not delete the original in that case.
- **The result is a new receipt** (`rct_…`) with `upload_method = api` and `uploader` set to the token's user. The original's uploader and any extracted text do not carry over.

---

## Interpreting a `403`

The two authorization layers fail the **same way**. A scope failure (the token lacks the required scope, or a `restricted` token hit an action with no scope declaration) and a Pundit policy failure (this user may not touch this record) both raise `Pundit::NotAuthorizedError`, which renders an identical body:

```json
{ "error": "not_authorized" }
```

with status `403`. **You cannot tell the two apart from the response.** Disambiguate by construction instead:

- **Rule out scope failure up front.** Request the [recommended scopes](#recommended-scopes-for-a-receipt-agent) before you start. If a call you know your scopes cover (e.g. `GET /transactions/missing_receipt`, which needs only `ledgers:read`) returns `403`, the token is missing a scope or `restricted` is misconfigured. Fix the token; do not retry per record.
- **Otherwise treat a `403` as a per-record skip.** Once the token is known good, a `403` on a specific `POST /receipts` almost always means the user isn't a member of that transaction's organization (`ReceiptablePolicy#upload?`). Skip that transaction and continue; transactions in the user's own organizations still succeed.

Error bodies a receipt agent will encounter (full taxonomy in [`standards.md`](./standards.md#error-responses)):

| Status | Body `error` | Meaning |
|--------|--------------|---------|
| `401` | `invalid_auth` | Token missing, expired, or invalid. Re-authenticate. |
| `403` | `not_authorized` | Missing scope **or** user not permitted for this record (indistinguishable). |
| `404` | `resource_not_found` | No record for that `txn_…` / `rct_…` id. |
| `400` | `invalid_record` / `invalid_operation` | Bad params (e.g. unsupported file type, missing `file`). |

---

## Receipt-Specific Best Practices

(General guidance such as token refresh, rate limits, and error shapes lives in [`standards.md`](./standards.md).)

- **Always pass `transaction_id`.** A receipt uploaded without one lands in the user's [Receipt Bin](#the-receipt-bin), and there is no single endpoint to attach a receipt in the Receipt Bin to a transaction afterward (only the [re-upload workaround](#linking-a-receipt-in-the-receipt-bin-to-a-transaction)). If you cannot confidently match a file to a transaction, skip it and flag it for a human rather than uploading it to the Receipt Bin.
- **Treat extraction and pairing as async.** Extracted fields aren't available in the create response.
- **Uploads aren't deduped.** The same file uploaded twice creates two receipts. Use `receipts:read` (`GET /receipts?transaction_id=…`) to check whether a transaction already has a receipt, and track handled `txn_…` IDs across runs.
- **Use `missing_receipt` to discover work.** `GET /api/v4/transactions/missing_receipt` lists the user's transactions still missing a receipt across all their organizations in one call. Scoped to one organization, `GET /api/v4/organizations/:id/transactions?filters[missing_receipts]=true` does the same. Both require `ledgers:read`.
- **Marking no/lost is a last resort, and human-gated.** Never call `mark_no_receipt` autonomously. It suppresses the missing-receipt signal before anyone has searched for the receipt, so it must require explicit, per-transaction authorization from a human who has confirmed the receipt cannot be found. The agent's `receipts:write` scope permits this call, so the boundary is behavioral, not enforced.
