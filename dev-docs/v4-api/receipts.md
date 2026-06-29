# Managing Receipts with the v4 API

A guide to working with **receipts** in the HCB v4 API. It covers what a receipt is and the endpoints specific to receipts.

> This guide only documents what is **receipt-specific**. For everything general (authentication & OAuth, object shape (`id`/`object`/`created_at`), pagination, error responses, rate limits) see [`standards.md`](./standards.md). For the scope model, see [`scopes.md`](./scopes.md).

---

## What Is a Receipt?

A **receipt** is an uploaded file (image, PDF, or CSV) documenting a transaction. It is a polymorphic attachment to a "receiptable" (usually a **transaction**, sometimes a reimbursement expense), or it can be **unattached**, sitting in the user's **receipt bin** awaiting a match. On upload, HCB asynchronously runs text extraction and suggests pairings between bin receipts and transactions missing one.

| | |
|---|---|
| Public ID prefix | `rct` (e.g. `rct_a1b2c3`) |
| API `object` value | `receipt` |
| Accepted file types | `image/*`, `application/pdf`, `text/csv` |
| Max file size | 50 MB |

> A "transaction" in v4 is an `HcbCode`, public-ID prefix `txn`. `transaction_id` means a `txn_…` ID.

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

OAuth Bearer tokens as described in [Authentication](./standards.md#authentication). Scopes are only enforced for tokens that also carry `restricted` (see [`scopes.md`](./scopes.md)). Use a `restricted` token for least privilege.

| Action | Endpoint | Required scope |
|--------|----------|----------------|
| Upload a receipt | `POST /api/v4/receipts` | `receipts:write` |
| Read transactions | `GET /api/v4/transactions/...` | `transactions:read` |
| List / delete receipts | `GET` / `DELETE /api/v4/receipts` | *(no scope declared yet)* |

> ⚠️ A `restricted` token is **deny-by-default**: it can only reach actions with an explicit scope declaration. The receipt index and delete don't declare one yet, so a strictly `restricted` token may get `403` on them until a scope is added. Scopes gate the token; [Pundit policies](#delete-a-receipt) gate the user. Both must pass.

---

## Endpoints

All receipt routes are [shallow and top-level](./standards.md#shallow-routing).

### Create a Receipt

```
POST /api/v4/receipts
```

This is the one endpoint that uses **`multipart/form-data`** rather than JSON, because a binary file can't be JSON-encoded.

| Param | Required | Description |
|-------|----------|-------------|
| `file` | yes | The receipt file (`image/*`, `application/pdf`, `text/csv`, ≤ 50 MB). |
| `transaction_id` | no | A `txn_…` ID. If present, attaches to that transaction (user must pass `ReceiptablePolicy#upload?`, i.e. member+ on the org). If omitted, the receipt goes to the user's **receipt bin**. |

```bash
# Attach to a transaction
curl -X POST https://hcb.hackclub.com/api/v4/receipts \
  -H "Authorization: Bearer hcb_<token>" \
  -F "transaction_id=txn_abc123" -F "file=@receipt.pdf"
```

Returns `201` with the [receipt object](#the-receipt-object). `upload_method` is set to `api` automatically; extraction and pairing run async after the response.

### List Receipts

```
GET /api/v4/receipts                          # the current user's receipt bin (unattached)
GET /api/v4/receipts?transaction_id=txn_abc   # receipts attached to a transaction
```

Returns an array of [receipt objects](#the-receipt-object).

### Delete a Receipt

```
DELETE /api/v4/receipts/:id     # :id is an rct_… ID
```

Governed by `ReceiptPolicy#destroy?`: bin receipts can be deleted only by the uploader; transaction receipts require member+ on the org (and unlocked); reimbursement-expense receipts require the report owner or org manager (and unlocked); admins always. Returns `{ "message": "Receipt successfully deleted" }`.

### Find Transactions Missing a Receipt

```
GET /api/v4/transactions/missing_receipt
```

Returns the authenticated user's transactions (across their Stripe cards) still missing a receipt, newest first, [paginated](./standards.md#pagination).

### Mark a Transaction as No / Lost Receipt

```
POST /api/v4/transactions/:id/mark_no_receipt    # :id is a txn_… ID
```

Removes the transaction from the missing-receipt list when no receipt exists. Requires `ReceiptablePolicy#mark_no_or_lost?` (member+). Returns `{ "message": "Transaction marked as no/lost receipt" }`.

---

## Receipt-Specific Best Practices

(General guidance such as token refresh, rate limits, and error shapes lives in [`standards.md`](./standards.md).)

- **Prefer attaching over the bin.** Pass `transaction_id` on create when you know the transaction; reserve the bin for receipts you can't yet match.
- **Treat extraction & pairing as async.** Extracted fields aren't available in the create response.
- **Uploads aren't deduped.** The same file uploaded twice creates two receipts; track handled `txn_…` IDs yourself.
- **Use `missing_receipt`** to enumerate transactions that need a receipt rather than scanning all transactions.
- **Mark, don't ignore.** If a transaction will never have a receipt, call `mark_no_receipt` so it leaves the missing list.
