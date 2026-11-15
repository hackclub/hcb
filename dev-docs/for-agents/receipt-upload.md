# Uploading Receipts with an Automated Agent

**What is HCB?** [HCB](https://hcb.hackclub.com) is Hack Club's fiscal-sponsorship and financial platform. Organizations on HCB — Hack Club events, nonprofits, hackathons, and similar projects — run their finances through it, spending via HCB cards, transfers, checks, and reimbursements. Each transaction should have a **receipt** attached for the organization's financial records. Attaching those receipts is the job this playbook describes.

A playbook for an automated agent that uploads receipt files from a local source and attaches each to the right HCB transaction via the v4 API. It covers **behavior**: which scopes to request, the run loop, how to match a receipt to a transaction, and the rules the agent must not break.

It assumes the receipt **reference** docs alongside it, and does not restate endpoint shapes, the scope model, or auth — follow the links:

- [`../v4-api/receipts.md`](../v4-api/receipts.md) — the receipt object, endpoints, scopes, and error shapes this playbook calls into.
- [`../v4-api/standards.md`](../v4-api/standards.md) — authentication & OAuth, pagination, object shape, error responses, rate limits.
- [`../v4-api/scopes.md`](../v4-api/scopes.md) — the scope model and how to request scopes on a token.

Base URL is `https://hcb.hackclub.com/api/v4`; every request carries an `Authorization: Bearer hcb_<token>` header.

---

## The OCR Contract (read this first)

The API exposes **no extracted fields** from a receipt. The [receipt object](../v4-api/receipts.md#the-receipt-object) carries only `url`, `preview_url`, `filename`, and `uploader` — never an amount, date, or merchant. Reading the file and pulling those values out (OCR for images and PDFs, parsing for CSVs) is **your job**.

Every matching heuristic below assumes you have already done this and hold a candidate `{ amount, date, merchant }` for each local file. HCB does run its own extraction and pairing asynchronously after upload, but those results are **not** exposed through the API and are not available to you.

---

## Scopes for a Receipt Agent

Request a **`restricted`** OAuth token for least privilege (see [the `restricted` scope](../v4-api/scopes.md#the-restricted-scope--gradual-rollout)) carrying exactly:

- **`receipts:write`** — upload receipts and attach them to transactions.
- **`ledgers:read`** — read transactions, to find the ones missing a receipt and match each local file by amount, date, and merchant.
- **`receipts:read`** — list a transaction's existing receipts (and the Receipt Bin), so the agent can skip transactions that already have one instead of uploading duplicates.

This set runs the full workflow and grants **no ability to move money**: it carries no transfer, ACH, disbursement, or card-grant scopes, and a `restricted` token is denied by default on every action it does not hold a scope for. See [Requesting Scopes on a Token](../v4-api/scopes.md#requesting-scopes-on-a-token) to register the app with these exact scopes. Agents may only use `restricted` OAuth tokens. Unrestricted OAuth tokens are not permitted for agents.

> ⚠️ **`receipts:write` is broad.** A single `receipts:write` scope authorizes uploading **and** deleting receipts **and** marking a transaction no/lost — the scope does not distinguish them. Keeping the agent from deleting or marking is therefore a matter of *these instructions*, not scope boundaries. See [Guardrails](#guardrails).

---

## The Run Loop

1. **Authenticate.** Obtain the `restricted` token above. See [Authentication](../v4-api/standards.md#authentication) for the token flow and [Requesting Scopes on a Token](../v4-api/scopes.md#requesting-scopes-on-a-token) for registering the app with these exact scopes.
2. **Discover transactions missing a receipt** via `GET /user/transactions/missing_receipt` — the authenticated user's **own card charges** missing a receipt, across every organization they belong to, in one call. This covers card charges on the user's own Stripe cards only; to find *every* transaction missing a receipt in an organization (other members' charges, non-card transactions), use the per-organization `GET /organizations/:id/transactions?filters[missing_receipts]=true` instead. Both require `ledgers:read`. [Paginate](../v4-api/standards.md#pagination) with the cursor.
3. **OCR each local file** into a candidate `{ amount, date, merchant }` (see [The OCR Contract](#the-ocr-contract-read-this-first)).
4. **Match** each file to a transaction by the rules in [Matching Receipts to Transactions](#matching-receipts-to-transactions). Optionally call `GET /receipts?transaction_id=…` to confirm the transaction does not already have a receipt.
5. **Upload** matched files with `POST /receipts`, always passing `transaction_id` (see [Create a Receipt](../v4-api/receipts.md#create-a-receipt)). Confirm a `201` before moving on.
6. **Skip what you cannot confidently match** — flag it for a human. Do **not** upload it to the Receipt Bin (see [Guardrails](#guardrails)).

Process per page rather than collecting everything first: match and upload as you page through step 2. This bounds memory and keeps every request well under the [30-second timeout](../v4-api/standards.md#request-size--timeouts) (page sizes and upload limits live there too).

---

## Worked Example

A single file, `costco-2026-06-02.pdf`, that OCR resolves to `{ amount: 48.72, date: 2026-06-02, merchant: "Costco" }`:

```bash
# 1. Find transactions missing a receipt (first page; follow the cursor for more)
curl -s "https://hcb.hackclub.com/api/v4/user/transactions/missing_receipt" \
  -H "Authorization: Bearer hcb_<token>"
# → returns transactions; scan for one whose |amount_cents| == 4872, e.g.
#   txn_9f3a2b  amount_cents=-4872  card_charge.spent_at=2026-06-02
#               card_charge.merchant.smart_name="Costco Wholesale"  card.last4="4242"

# 2. (optional) confirm it has no receipt yet
curl -s "https://hcb.hackclub.com/api/v4/receipts?transaction_id=txn_9f3a2b" \
  -H "Authorization: Bearer hcb_<token>"
# → []  , so it's safe to upload

# 3. Upload, attaching to the transaction
curl -s -X POST "https://hcb.hackclub.com/api/v4/receipts" \
  -H "Authorization: Bearer hcb_<token>" \
  -F "transaction_id=txn_9f3a2b" -F "file=@costco-2026-06-02.pdf"
# → 201 with the receipt object. Record txn_9f3a2b as handled and move on.
```

Why this is a confident attach: amount `4872` is an exact hit; merchant "Costco" fuzzy-matches `smart_name`; the receipt date (2026-06-02) matches `spent_at` (2026-06-02). Exact amount **plus two** corroborating signals. Had two transactions both shown `amount_cents=-4872`, you would disambiguate on merchant and `last4`; if still ambiguous, **skip and flag** rather than guess.

---

## Matching Receipts to Transactions

Matching compares two sources: the **receipt file**, which you must read or OCR yourself ([The OCR Contract](#the-ocr-contract-read-this-first)), and the **transaction object** from the transactions API. For card charges, the fields worth matching on are:

| Transaction field | Use for matching |
|---|---|
| `amount_cents` | Charge amount in cents. Negative for expenses; compare against the receipt total by absolute value. |
| `date` / `card_charge.spent_at` | `date` is the settlement date (often a day or two after purchase). `card_charge.spent_at` is the authorization time — the purchase moment a paper receipt is dated — so prefer it for date matching. |
| `card_charge.merchant.smart_name` / `.name` | Humanized and raw merchant name. `smart_name` is the cleaner one to compare. |
| `memo` | Transaction memo, often merchant-derived. |
| `card_charge.card.last4` | Last 4 of the card used. May be `null`. |
| `card_charge.wallet` | Mobile wallet used for the charge (e.g. `apple_pay`), when known; otherwise `null`. |

Heuristics, strongest first:

- **Amount must match.** Compare absolute values (`|amount_cents|` against the receipt total in cents). This is a hard filter: a different amount is a different transaction. Two caveats:
  - **Tips/gratuity.** Restaurant charges often settle higher than the printed subtotal. Allow the charged amount to exceed the receipt total by a plausible tip for restaurants; never allow it to be lower.
  - **Currency.** Foreign charges settle in USD while the receipt may be in another currency. If `card_charge.merchant.country` is non-US, lean on merchant and date rather than a raw amount comparison.
- **Dates must be close.** Compare the receipt date against `card_charge.spent_at` (the purchase/authorization day), not `date` (the later settlement day). A same-day match is the strong signal; allow a day or two of slack. A receipt dated well after the charge, or long before it, is a non-match.
- **Card last4.** If the receipt prints the last 4 digits of the card, a match against `card_charge.card.last4` is a strong corroborating signal, but `last4` can be `null` and many receipts omit it: treat a match as confirmation and a missing value as neutral, not a mismatch. A *mismatch* is also not disqualifying: a mobile wallet such as Apple Pay assigns each card a device-specific token (a Device Account Number), so the digits printed on the receipt can be that token's last 4 rather than the card's `last4`. When `card_charge.wallet` is set (e.g. `apple_pay`), treat a `last4` mismatch as expected. Use `last4` to confirm, never to rule out.
- **Merchant name.** Fuzzy-match the receipt's merchant against `smart_name` (fall back to `merchant.name` or `memo`). Normalize case and punctuation, and strip processor prefixes and location noise (e.g. `SQ *`, `TST* `, store numbers, city/state). A clear merchant match disambiguates when several transactions share an amount and date.
- **When in doubt, look it up.** A merchant name or transaction descriptor can be cryptic — an unfamiliar brand, a parent company, a payment-processor alias (`SQ *`, `TST*`), or a foreign merchant. If you have web-search capabilities, use them to resolve what a merchant or descriptor actually is, or to make sense of an unclear receipt, before deciding a match (for example, confirming that a receipt's storefront and a transaction's `smart_name` are the same business). Treat search as an aid to matching, never as a substitute for the amount and date checks above.

Combining the signals:

- Require an **exact amount match plus at least one** corroborating signal (close date, merchant, or last4) before attaching.
- If **multiple transactions** match on amount and date, disambiguate with merchant and last4. If still ambiguous, **skip and flag for a human** rather than guess: attaching to the wrong transaction is worse than leaving it unattached.
- **Only card charges expose merchant and card data.** ACH transfers, checks, donations, and disbursements have no `card_charge` block, so fall back to amount, date, and `memo` for those (uncommon for receipt uploads).

### Edge Cases

- **Multiple receipts per transaction.** A transaction can legitimately have several receipts (an itemized receipt plus a tip slip, say). The missing-receipt list only cares whether *at least one* exists. If you hold multiple files for the same charge, attach each with its own `POST /receipts`; don't try to merge them.
- **Itemized vs. total.** Match on the receipt **total** (including tax, and tip where it appears on the slip), not a line-item subtotal — that total is what settles on the card. See the tips/gratuity caveat above.
- **Split or partial receipts.** One file may cover several charges (split tender across cards), or one charge may span multiple receipt pages. Match on the amount that actually settled on the card. If a single file maps to multiple transactions, or several files map to one, and you cannot cleanly assign them, **skip and flag**.
- **Reimbursement expenses are out of scope.** Receipts can also attach to reimbursement-expense receiptables, not just card transactions. This playbook covers **card-charge matching only**; reimbursement-expense receipts follow a different workflow and are not handled here.

---

## Linking a Receipt-Bin Receipt to a Transaction

There is no endpoint that moves a receipt out of the [Receipt Bin](../v4-api/receipts.md#the-receipt-bin) onto a transaction. The mechanism — re-upload the file with a `transaction_id`, then delete the original from the Receipt Bin — is documented step by step in [the reference](../v4-api/receipts.md#linking-a-receipt-in-the-receipt-bin-to-a-transaction). For an agent, the rules that matter:

- **Order matters: delete only after a confirmed `201`.** If you delete first, or the re-upload fails, the file is gone.
- **A `403` on the re-upload** means the user isn't a member of the transaction's organization. Leave the original in the Receipt Bin and skip it.
- This is a **fallback**. The primary path is to **always pass `transaction_id` on upload** so a receipt never lands in the Receipt Bin in the first place (see [Guardrails](#guardrails)).

---

## Guardrails

The agent's scopes permit more than it should ever do. These boundaries are **behavioral**, not enforced by the token:

- **Always pass `transaction_id`.** A receipt uploaded without one lands in the user's [Receipt Bin](../v4-api/receipts.md#the-receipt-bin), and the only way to attach it afterward is the [re-upload workaround](#linking-a-receipt-bin-receipt-to-a-transaction). If you cannot confidently match a file to a transaction, **skip it and flag it for a human** rather than uploading it to the Receipt Bin.
- **Never move money.** The recommended scope set carries no money-movement scopes by design. Do not request more than `receipts:write`, `ledgers:read`, `receipts:read`.
- **Never `mark_no_receipt` autonomously.** Marking a transaction no/lost suppresses the missing-receipt signal before anyone has searched for the receipt. It must require explicit, per-transaction authorization from a human who has confirmed the receipt cannot be found. Your `receipts:write` scope permits the call, so the boundary is yours to honor.
- **Never delete** except as the final step of the [re-upload workaround](#linking-a-receipt-bin-receipt-to-a-transaction), and only after a confirmed `201`.
- **Uploads aren't deduped.** The same file uploaded twice creates two receipts. Use `GET /receipts?transaction_id=…` (`receipts:read`) to check whether a transaction already has one before uploading.
- **Store tokens securely.** Both the access token (`hcb_…`) and the refresh token grant API access — treat them as secrets. Keep them in a secret manager or environment variable; never hard-code, log, print, or commit them, and restrict file permissions on anything that persists them. On refresh the previous token may be invalidated, so store the new pair the same way. See [Token Expiry & Refresh](../v4-api/standards.md#token-expiry--refresh).
- **Resumability is yours to solve.** Uploads aren't deduped and the API keeps no per-agent state, so re-running over the same source can create duplicate receipts. Track which `txn_…` IDs (and which local files) you have already handled, and skip them on the next run. HCB does not do this for you; it is an integrator responsibility, out of scope for this API.
- **Keep a local paper trail of every mutation.** Log each mutative call you make — uploads (the resulting `rct_…` and the `txn_…` it attached to, plus the source file), deletions, re-uploads — with enough detail to reverse it. If the user later finds a mistake (a receipt attached to the wrong transaction, say), this log is the only way to know what to undo: delete the `rct_…` you created and re-attach the file to the correct transaction. The API keeps no per-agent history, so anything you don't record yourself is unrecoverable.
- **A `403` can mean two things, indistinguishably.** See [Interpreting a `403`](../v4-api/receipts.md#interpreting-a-403). Operationally: rule out a scope failure up front — a `403` on a call your scopes cover (e.g. `GET /user/transactions/missing_receipt`) means the token is missing a scope or `restricted` is misconfigured; fix the token, don't retry per record. Once the token is known good, treat a `403` on a specific `POST /receipts` as a per-record skip — it almost always means the user isn't a member of that transaction's organization. Skip and continue.
