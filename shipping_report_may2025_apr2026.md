# HCB Shipping Report: May 2025 – April 2026

A compilation of user-facing features and improvements merged to `main` in `hackclub/hcb` since May 1, 2025. Items that already have a post in [hcb-engr](https://github.com/hackclub/hcb-engr/tree/main/content/posts) are listed below with a ✅ badge and a link to the existing post — the rest still need writing.

Admin-only features, V4 API changes aimed at technical integrators, internal refactors, CI/test/dependency work, and one-off bug fixes have been excluded.

Source data: 2,292 merged PRs between 2025-05-01 and 2026-04-18.

---

## Already blogged (since May 2025)

These features shipped in this window and have a live post on the HCB engineering blog. Included here so the full picture is visible — no new writing needed, but the PRs are listed in case you want to credit contributors or link back.

### ✅ Organization Announcements (Tier 1)
Organizations can publish updates, newsletters, and announcements directly from HCB to their members.
- **Authors:** @Luke-Oldenburg, @polypixeldev, @garyhtou, @24c02, @davidcornu
- **PRs:** #10830 (core), #10904 (follow + monthly email + home highlight), #11056 (Atom feeds), #10893 (custom elements), #10974 (auto-follow organizers), #11077 (frontend polish)
- **Post:** [`organization-announcements`](https://github.com/hackclub/hcb-engr/tree/main/content/posts/organization-announcements)

### ✅ HCB Discord Bot
A Discord bot that notifies your team of HCB events — card charges, receipts, donations — with actionable buttons for attaching receipts and viewing transactions.
- **Authors:** @YodaLightsabr, @polypixeldev, @Luke-Oldenburg, @sampoder
- **PRs:** #11791 (core), #11839 (user & event integration tabs), #11871 (attach-receipt button), #12527 (view-transaction button), #12728 (PDF receipt support)
- **Post:** [`discord-bot`](https://github.com/hackclub/hcb-engr/tree/main/content/posts/discord-bot)

### ✅ Monthly Announcements
Automatically-scheduled monthly summaries of an organization's activity — donations, spending, cards — delivered as an announcement that members can follow.
- **Authors:** @Luke-Oldenburg, @polypixeldev
- **PRs:** #10975 (auto-scheduling), #11083 (callout), #11146 (spending summary blocks), #11299 (enable/disable lifecycle), #12018 (auto-enable job), #11945 (unlink from transparency)
- **Post:** [`monthly-announcements`](https://github.com/hackclub/hcb-engr/tree/main/content/posts/monthly-announcements)

### ✅ International Transfers via Wise
Send money in dozens of currencies via Wise, including ACH, SWIFT wires, and Interac — with live quotes, transparent FX fees, and a "Convert to Wise" shortcut on reimbursement reports.
- **Authors:** @YodaLightsabr, @davidcornu, @sampoder
- **PRs:** #11168 (international transfers), #11429 (international reimbursements), #11578 (quote + cost breakdown UI), #11783 (convert-to-Wise on reimbursements), #11268 (Interac support), #12449 ($50,000 cap), #12729 (Wise in transfer wizard)
- **Post:** Wise transfers blog (Nov 4, 2025 in the hcb-engr history)

### ✅ Event Affiliations
Link your event to a school, robotics team, or other institution you're affiliated with — unlocks special partner perks and a visual affiliation badge on your dashboard.
- **Authors:** @Luke-Oldenburg, @polypixeldev, @YodaLightsabr
- **PRs:** #10764 (core), #12709 (polymorphic affiliable), #12898 (remove button), #13131 (validation), #13326 (admin edit)
- **Post:** [`event-affiliations`](https://github.com/hackclub/hcb-engr/tree/main/content/posts/event-affiliations)

### ✅ Receipt Status in Emails
Receipt upload confirmation emails now show a dynamic image of your receipt and its approval/rejection status, so you can see at a glance whether everything's in order.
- **Author:** @polypixeldev
- **PRs:** #10491 (dynamic image), #11873 (works signed out), #11906 (PNG switch), #12099 (higher resolution)
- **Post:** [`receipt-status-emails`](https://github.com/hackclub/hcb-engr/tree/main/content/posts/receipt-status-emails)

### ✅ HCB Mobile Release
The HCB mobile app (iOS + Android) launched: manage cards, upload receipts, approve reimbursements, and more from your phone. Apple Smart Banner + Android App Links auto-route web links into the app when installed.
- **Authors:** @Mohamad-Mortada, @YodaLightsabr and the mobile team
- **PRs:** #10971 (mobile deep-linking), #12305 (install stats), #12383/#12384 (smart banner + app links), #11360 (sub-orgs in mobile nav)
- **Post:** [`hcb-mobile-release`](https://github.com/hackclub/hcb-engr/tree/main/content/posts/hcb-mobile-release)

### ✅ UI3 — HCB's visual refresh
A site-wide refresh of HCB's visual language — new colors, typography, component polish, rolled out across the core product.
- **Authors:** @lachlanjc, @garyhtou, @manuthecoder and the design team
- **PRs:** #7741 (visual refresh across core components), #8474 (UI3), plus countless component-level follow-ups
- **Post:** UI3 post (Dec 24, 2025 in hcb-engr history)

### ✅ Mobile Navigation: Desktop Sidebar on Phones
Mobile users now see the same sidebar navigation as desktop — no more cramped hamburger menu for power users.
- **Author:** @manuthecoder
- **PR:** #13148
- **Post:** [`mobile-navigation-improvements`](https://github.com/hackclub/hcb-engr/tree/main/content/posts/mobile-navigation-improvements)

### ✅ Transfer Improvements
A cleaner, more consistent transfer flow across ACH, check, wire, Wise, and HCB-to-HCB: the transfer wizard, improved "in-transit" filter, routing-number hints, and reliable currency handling.
- **Authors:** @manuthecoder, @Luke-Oldenburg, @sampoder
- **PRs:** #12729 (wizard), #12358 (in-transit filter), #13376 (routing-number hints), #11222 (currency warnings)
- **Post:** Transfer improvements (Mar 31, 2026 in hcb-engr history)

### ✅ Organization Settings Change Notifications
Organization members get notified whenever transparency mode or monthly announcements are toggled on or off.
- **Author:** @polypixeldev
- **PR:** #12036
- **Post:** [`organization-settings-notifications`](https://github.com/hackclub/hcb-engr/tree/main/content/posts/organization-settings-notifications)

### ✅ Redesigned Organization Invitations
A fresh UI for inviting teammates into an organization — clearer hierarchy, better role explanations, and smoother acceptance flow.
- **Authors:** @manuthecoder, @Luke-Oldenburg, @garyhtou
- **PRs:** #11970 (invite flow redesign), #12653 (UI hierarchy improvements)
- **Post:** [`redesigned-organization-invitations`](https://github.com/hackclub/hcb-engr/tree/main/content/posts/redesigned-organization-invitations)

### ✅ Summary Notification Settings
A dedicated preferences page for choosing which periodic summary emails you get (monthly spend, donation digests, announcement follow-ups, etc.).
- **Authors:** @Luke-Oldenburg, @garyhtou
- **PR:** #13371
- **Post:** [`summary-notification-settings`](https://github.com/hackclub/hcb-engr/tree/main/content/posts/summary-notification-settings)

### ✅ Sort Your Invoices
Invoices are now sortable by amount, status, date, and more — click a column header to sort.
- **Author:** @manuthecoder
- **PRs:** #10651 (sorting ability), #13255 (refactored sort header logic)
- **Post:** [`sort-your-invoices`](https://github.com/hackclub/hcb-engr/tree/main/content/posts/sort-your-invoices)

---

## Important features shipped (blog-post-worthy — not yet blogged)

Each of these would merit its own blog post — they're substantial, visible to nearly all users, and introduce new capabilities or rethink a major flow.

### 1. Sub-organizations: nest orgs inside orgs
Hack Club organizations can now create sub-organizations — perfect for chapters, project teams, or event tracks under a single parent umbrella. Sub-orgs inherit settings from their parent and roll up into the organization hierarchy.
- **Author:** @sampoder
- **PRs:** #9739 (core), #11756 (sub-event CSV), #11932 (dedicated creation page), #11907 (scoped tags), #11735 (URL prefill), #11196 (command bar search)

### 2. Card grant pre-authorizations (with AI fraud scanning)
Card grantees can request pre-approval for upcoming purchases. Organizers see the request, and HCB's AI quickly scans supporting documentation to flag suspicious requests. Pre-auths can be toggled per-grant.
- **Authors:** @YodaLightsabr, @Luke-Oldenburg, @polypixeldev
- **PRs:** #10820 (core), #10845 (organizer review), #10848 (fraud bug fix), #11599 (disable toggle)

### 3. Block merchants and categories on card grants
Organizers can lock card grants down to specific merchant category codes or block individual merchants. Perfect for "food only" or "no Uber Eats" style grants.
- **Author:** @YodaLightsabr
- **PR:** #10968

### 4. Freeze your card grant
Card grant holders can now freeze their own grant from their dashboard — a safer "pause" for unknown charges without having to contact an organizer.
- **Author:** @Luke-Oldenburg
- **PR:** #10473 (plus #10513 adding freeze-by-manager lockout)

### 5. Card grant overhaul: a brand new overview page
An entirely redesigned Card Grants index page and management interface — giving organizers a much cleaner view of every grant they've issued, who has them, and what's been spent.
- **Author:** @Luke-Oldenburg
- **PRs:** #10541 (overview), #12166 (index overhaul), #10869 (UI refresh pt. 2), #10611/#10942 (design polish)

### 6. Bulk send card grant invites via CSV
Upload a CSV and invite dozens of card grant recipients in one shot, each with their own grant amount and spend-by date — replacing the one-at-a-time invite flow.
- **Authors:** @jeninh, @sampoder
- **PRs:** #12426, #12558, #12113 (custom messages), #12437 (invitation expiration)

### 7. One-time use card grants
Issue a grant that self-destructs after a single transaction — for the odd one-time purchase that shouldn't leave a live card behind.
- **Author:** @polypixeldev
- **PR:** #10548 (#11222 added a one-time indicator)

### 8. Individually customize card grant expiration dates
Expiration dates can now be set per card grant instead of all grants sharing the organization-wide default.
- **Author:** @Luke-Oldenburg
- **PRs:** #12301, #12996

### 9. Donation tiers with publishing
Organizations can now set up donation tiers (think: "Bronze/Silver/Gold"), each with its own amount and benefits, and publish them directly on their donation page.
- **Author:** @manuthecoder
- **PRs:** #10676 (initial tiers), #12718 (publishing), #13219 (signed-out donations on tiers), #10819 (enhancements)

### 10. Sign contracts directly inside HCB
Organizations can now sign their fiscal sponsorship contract from inside HCB — no more DocuSign round-trip to get started.
- **Author:** @polypixeldev
- **PR:** #12377

### 11. Statement of Activity: professional accounting reports
A proper Statement of Activity report for organizations, with detailed category-by-category transaction views and XLSX export. Auditors can view it too.
- **Authors:** @garyhtou, @manuthecoder, @polypixeldev, @YodaLightsabr
- **PRs:** #11437 (alpha), #11541 (XLSX), #11586 (auditor access), #13395 (detailed view), #13398–#13404 (automated accounting categorization for disbursements, transfers, card grants)

### 12. Automatic logout after inactivity
Sessions now expire after a period of inactivity (max two weeks), protecting accounts where a device is left signed in.
- **Author:** @Luke-Oldenburg
- **PR:** #11596

### 13. Second factor required to enable 2FA
Setting up two-factor authentication now requires a second authentication factor first — closing a gap where a compromised session could enable 2FA and lock out the real user.
- **Author:** @sampoder
- **PR:** #12441 (plus #12371, disallow SMS as the only factor for fresh users)

### 14. Sudo Mode with security keys for sensitive actions
HCB now enters a "sudo mode" re-authentication for high-value actions — ACH, wires, and checks over $500, plus any time you view full card details. WebAuthn (hardware security keys / Face ID / Windows Hello) is fully supported as a factor.
- **Authors:** @davidcornu, @sampoder
- **PRs:** #11048 (WebAuthn), #11133 (ACH), #11135 (wires), #11142 (checks), #11156 (card details), #12621 (direct uploads)

### 15. Refer new teenagers, climb the leaderboard
Teenagers can create personal referral links to invite new users, with custom redirect destinations. A live leaderboard ranks top referrers.
- **Authors:** @YodaLightsabr, @Luke-Oldenburg
- **PRs:** #12323, #12324, #12330 (leaderboard)

### 16. Teen Perks expansion
A major expansion of teen-only perks — any organization with at least one teen member can see and redeem perks, there's a teen fee waiver for eligible teen-run orgs, and an active-teen leaderboard.
- **Author:** @Luke-Oldenburg
- **PRs:** #11547 (perks visibility), #11742 (fee waiver), #11612 (leaderboard)

### 17. Document preview in your browser
Receipt and attachment files (CSVs, Word docs, and more) now preview inline in HCB instead of forcing a download.
- **Author:** @sampoder
- **PR:** #11127

### 18. Balance graph
A beautiful balance-over-time graph on your organization dashboard, letting you see cash position at a glance.
- **Author:** @manuthecoder
- **PR:** #13137

### 19. Tap to Pay support
Groundwork for paying in person by tapping a physical or virtual HCB card at a supported terminal, via a new payment intent route.
- **Author:** @Mohamad-Mortada
- **PR:** #13206

### 20. Cancel recurring donations
Organization managers can now cancel recurring donations from within HCB — previously this required a support ticket.
- **Author:** @rluodev
- **PR:** #11436

### 21. Donation goal reached: a celebratory email
When your organization hits its donation goal, everyone on the team gets an email announcing it.
- **Author:** @polypixeldev
- **PR:** #10723

### 22. Atom feeds and follow for organization announcements
Complementary to organization announcements themselves: users can "follow" announcements to get a monthly digest email, and every org's announcements are also available as an Atom feed for RSS readers.
- **Authors:** @Luke-Oldenburg, @24c02, @polypixeldev
- **PRs:** #10904 (follow + monthly email + home highlight), #11056 (Atom feeds), #11083 (monthly callout), #11073 (new block editor UI), #11146 (spending summary blocks)

---

## Small wins shipped (summary-post-worthy)

These are real improvements users will notice, but aren't big enough to merit a dedicated post. A single rollup blog post would work well.

### Filters, search, and command palette
- **Ledger amount search** — search the ledger by exact amount. @leowilkin (#10533)
- **Amount range slider filter** — slide to filter by amount range. @manuthecoder (#11472)
- **Date range picker** — pick a calendar range to filter transactions. @manuthecoder (#11502)
- **Ledger category filter** — narrow the ledger to a single transaction category. @polypixeldev (#11391)
- **Merchant filters on the ledger.** @garyhtou (#11434)
- **Incoming/outgoing transaction filter.** @Sarvesh-Mk (#10952)
- **Filter cards by inactive status.** @Luke-Oldenburg (#10414)
- **Wise transfer filter in the ledger.** @Copilot (#12357)
- **Transactions in the command palette** — find any transaction via ⌘K. @manuthecoder (#13104)
- **Card grants in the command palette.** @manuthecoder (#13441)
- **Search reimbursement reports by requested reviewer.** @Sarvesh-Mk (#10921)

### Card grants polish
- **Customizable card grant invite message.** @Luke-Oldenburg (#12113)
- **Card grant invitation expiration dates.** @Copilot (#12437)
- **Card grants list visible for all org types.** @Luke-Oldenburg (#13211)
- **Card name now shown on My Cards.** @Luke-Oldenburg (#13410)
- **Large "card declined" banner on the grant page.** @manuthecoder (#13239)
- **Refund clarification on canceled cards.** @Luke-Oldenburg (#13213)
- **Withdraw 100% of a card grant balance in one go.** @sampoder (#12528)
- **Show "add tag" button on grant page transactions.** @polypixeldev (#10380)

### Donations & invoices
- **Donate button on the event homepage.** @Luke-Oldenburg (#12304)
- **Streamlined invoice creation UI.** @manuthecoder (#9083)
- **Invoice filters.** @manuthecoder (#10645)
- **Donors can edit their own donor details.** @sampoder (#10355)

### Reimbursements
- **Convert a reimbursement report to a Wise international transfer with one click.** @YodaLightsabr (#11783)
- **Show payout method in reimbursement review emails.** @sampoder (#12652)
- **Managers can change reimbursement currency.** @Luke-Oldenburg (#13175)
- **Processing time displayed on reimbursement reports.** @Luke-Oldenburg (#13117)
- **Past reimbursed events now appear in My Reimbursements.** @Luke-Oldenburg (#13212)
- **Currency displayed on the reimbursement index when needed.** @YodaLightsabr (#13267)
- **Email address shown on reimbursement reports.** @Luke-Oldenburg (#10570)
- **Bank name shown for Wise reimbursements.** @YodaLightsabr (#12171)

### Transfers, checks, and payouts
- **Reissue stopped checks.** @sampoder (#11680)
- **Stop and reissue checks directly from the UI.** @Luke-Oldenburg (#13016)
- **Confirmation dialog for reimbursements that would make an account go negative.** @Copilot (#11029)
- **Interac → Interac e-Transfer renaming for clarity.** @Badbird5907 (#13392)
- **"Name on Account" shown for every payout method.** @Mohamad-Mortada (#13168)
- **Wise transfer option in the transfer wizard.** @manuthecoder (#12729)
- **Currency warnings on transfer forms.** @sampoder (#11222)
- **Automatic currency extraction from receipt text.** @YodaLightsabr (#11327)

### Receipts & notifications
- **SMS alerts when a card is locked for a missing receipt.** @YodaLightsabr (#10673)
- **Copy-receipt-email button on every transaction.** @YodaLightsabr (#12699)
- **Low spending balance warning email.** @polypixeldev (#10493)
- **Dynamic receipt status images in receipt upload confirmation emails.** @polypixeldev (#10491)
- **Discord notification now has an "attach receipt" button on card charges.** @YodaLightsabr (#11871)
- **Discord notification now has a "view transaction" button.** @sampoder (#12527)
- **Salary account transactions no longer trigger missing-receipt alerts.** @Luke-Oldenburg (#11805)

### Security
- **Card locking now has a 24-hour buffer to prevent accidental locks.** @sampoder (#12442)
- **Member-role users can view check deposit images.** @garyhtou (#11473)

### Applications & onboarding
- **Application unarchiving.** @polypixeldev (#13181)
- **Onboarding videos embedded in the application flow.** @polypixeldev (#13324)
- **URL parameter prefilling for sub-organization forms.** @Copilot (#11735)

### UI / polish
- **Canceled cards now display cut in half.** @Luke-Oldenburg (#10485)
- **Account Numbers page redesign and modal bug fixes.** @Luke-Oldenburg (#13224)
- **Fading indicator on overflowing callouts for scroll discoverability.** @polypixeldev (#13334)
- **Tappable tooltips on mobile.** @manuthecoder (#12468)
- **Default seasonal theme off for non-teenage users.** @sampoder (#12538)
- **Earlier-today subtitle on recent transactions.** @manuthecoder (#10372)
- **Show the latest HCB announcement on the homepage.** @Luke-Oldenburg (#11324)
- **Hide disabled items from event settings nav.** @Luke-Oldenburg (#13280)
- **Apple Smart Banner + Android App Links for HCB Mobile.** @Mohamad-Mortada (#12383, #12384)
- **Enable tag updates directly from the HCB code popover.** @polypixeldev (#10482)
- **Transaction category added to event CSV exports.** @garyhtou (#11546)
- **Stripe card: swapped the expiration date and CVV positions for readability.** @24c02 (#10995)
- **Stripe card address can be copied by line.** @Luke-Oldenburg (#10554)

---

## Notes on scope

- **Date range:** 2025-05-01 → 2026-04-18
- **Total merged PRs reviewed:** 2,292
- **Excluded categories:** admin panel features, V4 API additions aimed at technical integrators, internal refactors, CI/test/dependency work, and bug fixes without visible user impact.
- **Already blogged:** listed at the top with links to the existing `hcb-engr` posts.

When drafting individual posts, the PRs listed are a good jumping-off point for screenshots, commit examples, and contributor credit.
