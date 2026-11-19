# HCB voice & copy guide (DRAFT v0, for review)

> Status: first draft, built from what's already in the codebase, landing page, and help center.
> Every rule cites the evidence it came from. Items marked **[decide]** are open questions:
> the codebase disagrees with itself and someone needs to choose.

---

## 1. Who's talking

HCB is a fiscal sponsorship platform built by a nonprofit (Hack Club) for other nonprofits,
clubs, hackathons, and teams. A lot of those teams are run by teenagers. HCB holds their money,
which is the thing they care most about getting right.

So the voice is **a friendly, competent teammate who handles money carefully**. Think of the
person on the ops team who answers your email in 10 minutes: casual, direct, and never vague
about where your money is.

> "Powerful financial tools built by our nonprofit, for yours." (landing page)
>
> "HCB is not a bank, we're a fiscal sponsor…" (apply flow, `event/applications/_begin`)

## 2. Voice principles

### 2.1 Plain over polished
Use short sentences and everyday words. Explain finance terms or skip them. Our users include
16-year-olds running their first hackathon.

- ✅ "A card can only spend money your organization actually has." (help center)
- ✅ "The funds are available to spend right away." (`donation_mailer/first_donation_notification`)
- ❌ "Funds have been made available for disbursement."

### 2.2 Specific about money and consequences
When copy touches money, access, or privacy, say exactly what happens, to whom, and whether it
can be undone. Accuracy beats reassurance. Recent copy PRs all moved in this direction:

- hackclub/hcb#14791 (transparency mode) added: "A merchant name paired with an exact amount can
  be enough for a visitor to work out where and when a purchase was made."
- hackclub/hcb#14601 (card locking) split one "your cards work again" email into two, because
  the reassuring version wasn't true when an admin had only suppressed the lock.
- "Are you sure you want to do this? Unlike freezing a card, this can't be reversed."
- "Refunds received while frozen will still process and be returned to the card."

### 2.3 Always say what's next
Every status, error, or email should leave the reader knowing their next step.
hackclub/hcb#13003 exists because the activation email "doesn't really tell users what to do
next."

- ✅ "Please verify your phone number in your settings." (after "A verified phone number is required to issue a card.")
- ✅ "That tax form isn't finished processing yet. Try again in a few minutes."
- ❌ "Something went wrong." (with nothing after it)

### 2.4 Warm, human, a little playful, in the right places
We're people, not a bank. Contractions, "Hi there," "Congrats!", "We're here to help!",
a 🎉 on a first donation. But the jokes live in **designated spots** (§4). Product copy that
moves money stays straightforward.

### 2.5 Know who's reading
Write for the person on the screen. hackclub/hcb#12417 changed "as you spend more money" to
"you"/"they" depending on whether an organizer or a public visitor is reading the transparency
page. Same idea: don't show "Invite your team" to someone who can't.

### 2.6 Professional, not stiff
hackclub/hcb#12559 replaced "teenagers (< 18)" with "teenagers" because the symbol "looks
unprofessional." Don't use shorthand symbols, internal jargon, or model names (`HcbCode`,
`Event`, `canonical transaction`) in copy users see.

## 3. Tone by context

The voice stays the same everywhere. The tone changes with the stakes.

| Context | Tone | Example from the codebase |
|---|---|---|
| Flavor text, seasonal, raffles, dev mode | Full goofball. Puns, memes, lowercase. | "Putting the 'fun' in 'refund'" |
| Celebrations (first donation, approval, money arrived) | Excited. Exclamation point and emoji OK. | "Payment from {sponsor} has arrived 💵" |
| Everyday UI (labels, hints, empty states) | Calm, brief, helpful | "No transactions yet" |
| Success flashes | Short and confirming | "Card activated!" / "Check has been sent!" |
| Errors & declines | Calm, specific, no blame, what to do next | "We couldn't send this contract for signing. Please review the details and save again to retry." |
| Irreversible / security / compliance | Serious and exact. No jokes, no emoji. | "Voided invoices can not be paid and this action cannot be undone." |
| Legal and fiscal-sponsorship statements | Exact wording. Don't paraphrase. | "…fiscally sponsored by The Hack Foundation (d.b.a. Hack Club), a 501(c)(3) nonprofit (EIN: 81-2908499)." |
| Admin-only tools | Terse is fine. Correct beats pretty. | "Mark as rejected? This requires you to communicate to the organizer about the reason why." |

## 4. Where personality lives (and where it doesn't)

**Yes:** `FlavorTextService`, seasonal/holiday treatments, the raffle, the "Explore Hack Club"
cards, celebratory emails, dev-only strings.

**No:** money movement, declines, fraud, security notices, tax and legal text, rejections,
anything sent to a donor or sponsor who isn't a Hack Clubber. A donor receipt is read by
someone's grandparent or a corporate AP department.

## 5. Mechanics

### Naming
- **HCB**: always all caps. Never "Hack Club Bank" (the old name; the branding page says not to
  use it), never "Hack Club HCB," never "the Bank."
- **HCB is not a bank.** Say "fiscal sponsor" / "fiscal sponsorship platform." The money lives in
  a "restricted fund" at a partner bank (Member FDIC). Getting this wrong is a compliance problem,
  not just a style problem.
- **Hack Club** is the org. **The Hack Foundation (d.b.a. Hack Club)** is used only in legal and
  tax contexts.
- **Organization**, not "event." `Event` is the model; `en.yml` already maps it to "Organization."
  Legacy strings like "your event's HCB card" and "Event un-hidden" should be changed.
- **Sub-organization**, hyphenated.
- People: **members / managers / readers** (the role names), **team**, **cardholder**, **donor**,
  **sponsor**, **contractor**, **payee/recipient**. "Organizer" is fine in admin copy; in user
  copy, prefer "team member" or the role name. **[decide]**
- Us: **"we"** in UI and email; **"the HCB team"** when the team is named. Hack Club staff
  writing to users call themselves "your point of contact" or "your HCB representative" (both
  appear). **[decide: pick one]**

### Capitalization
- **Sentence case** for everything: buttons, headings, tabs, table headers, email subjects,
  labels. Already a written rule in `dev-docs/code_style.md` and on the landing page/help center.
  - ✅ "Get reimbursed", "Order a card", "Start application"
  - ❌ "Organizer's Email Address", "Start Date" (both exist today)
- Capitalize proper nouns and product names: HCB, Google Workspace, Receipt Bin, Transparency
  Mode? **[decide]**. The code says "transparency mode" (lowercase) almost everywhere; Receipt
  Bin is capitalized as a feature name.

### Spelling and punctuation
- **American English.** "canceled" (209 uses) not "cancelled" (9), "itemized" not "itemised"
  (hackclub/hcb#13916), "color" not "colour" (the card-logo hint currently says "colour").
- **Oxford comma**, always (landing page and app both use it).
- **Contractions** are encouraged: "can't", "we'll", "you're".
- **Exclamation points**: one at most, and only for good news. Not in errors, not in warnings.
  "Card frozen!" is borderline: freezing usually happens because something's wrong. **[decide]**
- **Ellipses** only for loading states ("Loading admin tools…").
- **Numbers and money**: use `render_money` / `.format` output (`$1,250.00`); write "7%" not
  "seven percent"; spell out durations in prose ("two business days") or use numerals; just be
  consistent within a string.
- **Em dashes**: used 134 times in the app, almost never on the landing page/help center.
  **[decide]**: keep (with no spaces: "fund—a privatized") or replace with commas/periods.
- **Apostrophes and quotes**: mostly straight (`'`), with ~96 curly (`’`). **[decide]**
- **Emoji**: welcome in celebratory emails and fun spots (🎉 💵 🚀 👋). Not in errors, security,
  legal, or donor-facing receipts. Never as the only way something is communicated.

### Dates and times
- Show times in the reader's time zone when we know it, and say so when we don't.
- "Jan 5" style in subjects/flash messages; "January 5th" in prose (both exist; matches
  `strftime` usage). **[decide]**

## 6. Patterns

### Success flash messages
`<Thing> <past-tense verb>.` Drop "Successfully" (18 uses); it adds nothing.
- ✅ "Card activated!", "Expense updated.", "Comment created."
- ❌ "Card cancelled successfully", "Successfully topped up grant."
- Pick one ending. Today we have "Card frozen!" and "Card frozen", "Card defrosted!" and
  "Card defrosted". **Proposal:** period for routine, "!" for good news.

### Error messages
What happened + why (if we know) + what to do. Use "we couldn't…" instead of "failed to…" or
"error while…".
- ✅ "We couldn't send this contract for signing. Please review the details and save again to retry."
- ❌ "Failed to cancel card", "Error activating address", "Something went wrong" on its own
- Never show raw codes (`invalid_operation`, `stripe_error`) to a person. API error keys are
  fine in the API itself.

### Confirmation dialogs
"Are you sure you want to <verb> <thing>?" + one consequence sentence when it matters.
- Today there are three forms: "you want to" (57), "you'd like to" (11), "you would like to" (7).
  **Proposal:** standardize on "Are you sure you want to…?"
- For destructive or irreversible actions, always add the consequence: "This can't be undone."
  (not "can not").

### Empty states
"No <things> yet" (+ an action if the viewer can take one).
- ✅ "No donations yet", "No invoices yet", "Get started by adding an expense"
- Keep "Nothing to see here" for read-only/public views only.

### Hints and helper text
One or two sentences in the second person. State limits plainly.
- ✅ "Plastic cards can only be shipped within the US."
- ✅ "At most sixteen characters long; used on statement descriptors and printed on your organization's HCB card."

### Emails
- **Subject:** sentence case, specific, includes the org name when relevant. `[Org name]` prefix
  for org-scoped notifications (already used for grants and announcements). Emoji only for good
  news.
- **Greeting:** "Hi {first name}," when we know it; otherwise "Hi there," / "Hi all,".
- **Body:** lead with the news in the first sentence. Then details, then the next step as a link.
  Short paragraphs.
- **Sign-off:** today we use "Best," (36), "From," (34), "Warmly," (8), "—HCB team" (3) and both
  "The HCB Team" (103) and "The HCB team" (13). **[decide]** Proposal: "Best,<br>The HCB team"
  (lowercase "team" follows our sentence-case rule, but "Team" is the majority today).

## 7. Word list

| Use | Avoid | Why |
|---|---|---|
| HCB | Hack Club Bank, the bank | Branding page |
| organization | event, org (in UI) | `en.yml` model name |
| fiscal sponsor(ship) | bank, banking | We're not a bank |
| canceled / canceling | cancelled / cancelling | American English, majority usage |
| sign in (verb), login (noun: "login code") | log in (verb) | "sign in" 36 vs "log in" 6 in views |
| email | e-mail | |
| reimbursement report | expense report | product term |
| card grant | grant card (except for the physical card) | product term |
| transfer **[decide]** | disbursement (user-facing) | "disbursement" is the model name, but it still shows up in user views (`card_grants/`, `transactions/`) |
| can't be undone | can not be undone | spelling |
| we couldn't… | failed to… / error while… | human voice |

## 8. What the copy routine should and shouldn't touch (proposed)

**In scope:** user-facing strings in `app/views/**`, flash messages in `app/controllers/**`,
mailer subjects and bodies, `config/locales/*.yml`, `aria-label`s and tooltips.

**Out of scope / hands off:**
- `FlavorTextService`, seasonal/raffle/dev strings: they're meant to break the rules.
- Legal/compliance/fiscal-sponsorship statements, the agreement, tax text.
- Bank memo strings and regexes (`"Hack Club Bank PAYOUT"`): data, not copy.
- API error keys and API response strings (v3/v4 contracts).
- Admin-only views: lower priority. Fix real errors, skip polish.

## 9. Source notes

- **Codebase:** about 1,000 ERB views, controller flashes, about 90 mailer subjects, empty states,
  confirm dialogs, `dev-docs/code_style.md` (sentence case), `static_pages/branding` (naming rules),
  and recent copy PRs (hackclub/hcb#14791, #14601, #13916, #13003, #12559, #12417).
- **Landing page** (hackclub.com/fiscal-sponsorship): "we/you," mission-led, sentence case,
  Oxford comma, few exclamation points, no emoji, no em dashes.
- **Help center** (help.hcb.hackclub.com): neutral and procedural, with "HCB" as the subject
  ("HCB can't reimburse…"). It's written by contractors, so it's used here only for mechanics
  (sentence case, naming), not for voice.
