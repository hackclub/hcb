# FIRST Home Page — Community / Team Members

**Date:** 2026-04-29
**Page:** `/first` (rendered by `app/views/users/first/index.html.erb` via `Users::FirstController#index`)

## Problem

The `/first` landing page tries to convert FIRST robotics users into HCB users, but it currently lacks social proof. People are far more likely to sign up and engage when they see that peers from their team are already on HCB. We want to surface that signal — first names and profile pictures only — at the moments where it matters most.

Two distinct moments:

1. **The user's team is already on HCB** (an `Event` exists with a matching FIRST affiliation). They should see who from the team is already on HCB right next to the existing "Request to join" CTA.
2. **The user's team is *not* on HCB, but ≥1 teammate has signed up individually.** They should see a peer signal that their teammates are interested, paired with a role-aware CTA to push the team toward setting up an org.

If neither condition is met (no teammates, no org), nothing is shown. We never invent or stretch social proof.

## Privacy guardrail

Only **first names** and **profile avatars** are ever displayed. No last names, emails, roles, or any other identifying info. The current user is always excluded from both the avatars and the names line.

## Context 1 — Team org exists on HCB

### Where

Folded **into the existing "Request to join" card** at `app/views/users/first/index.html.erb:108-129`. No new card.

### What changes in the card

The current card contains: heading, body copy ("…your team is already running on HCB! Request to join their organization, and once you're approved we'll automatically sign you up for our 3D printer raffle…"), and a disabled "Request to join" button.

Add, **above the button** (between the body paragraph and the button container):

- An `.avatar-row` of up to 5 org-member avatars at 30px
- A names line directly under it: e.g. `Maya, Eli, and 3 others are on this team`
- If exactly 1 other person, the line says `Maya is on this team`
- If 2 people, `Maya and Eli are on this team`
- If 3+ people, `<first>, <second>, and N others are on this team` (N = total org members − 2, excluding self)
- If the row has 0 members after excluding self (e.g., the user is the sole member), the avatar-row + names line are hidden entirely. The rest of the card stays as it is today.

### Data — who is an "org member"?

Org members are users with an active `OrganizerPosition` on the matching `Event` (where the event has a `first` affiliation with the same `league` and `team_number` as the user's affiliation).

Pseudocode in the controller:

```ruby
event_ids = Event::Affiliation
  .where(affiliable_type: "Event", name: "first")
  .where("metadata ->> 'league' = ?", affiliation.league)
  .where("metadata ->> 'team_number' = ?", affiliation.team_number)
  .select(:affiliable_id)

event = Event.find_by(id: event_ids) # at most one expected in practice

@team_org_members = event&.organizer_positions
                         &.joins(:user)
                         &.where.not(user_id: current_user.id)
                         &.order(...) # see Sort below
                         &.limit(5)
                         &.map(&:user)
```

(The exact association names should match what's already in `Event` — `organizer_positions` and `users` are present today; the controller code already uses `current_user.events`. Implementation may need to filter to non-archived/active positions; check existing scope conventions in the project.)

### Sort

Within the limit of 5:

1. **Verified users first** (verified > unverified)
2. Then by **org role**: `manager` > `member` > `reader`
3. Tiebreak by `OrganizerPosition.created_at DESC` (most recently joined the org)

This ordering is stable across requests — no random shuffling.

## Context 2 — Team org does NOT exist on HCB

### Where

A **new card immediately below the user's affiliation card** (i.e., inserted between `app/views/users/first/index.html.erb:46` and the start of the raffle section at line 48).

The card uses the standard `.card` style (white background) — *not* the dark promo card style reserved for raffles. This is informational, not promotional.

### Card contents

- Heading: `Your teammates are on HCB`
- An `.avatar-row` of up to 5 teammate avatars at 30px
- Names line: `Maya, Eli, and 1 other from <LEAGUE> #<TEAM_NUMBER> have signed up for HCB.` Same singular/plural rules as Context 1.
- Sub-copy: `Get your team's organization set up to fundraise and spend together.`
- Role-aware CTA button (see below)

### Role-aware CTA

Based on the current user's `affiliation.role`:

| Role                                  | CTA                                  | Action                                                                                            |
| ------------------------------------- | ------------------------------------ | ------------------------------------------------------------------------------------------------- |
| `student_leader` or `student_member`  | "Email your advisor about HCB →"     | Opens the existing modal (`#modal` at `index.html.erb:226-244`) using `data-behavior="modal_trigger"` |
| `head_coach` or `mentor_advisor`      | "Start your team's organization →"   | Plain link to `/apply` (the existing `apply` route — no prefill params, since the route doesn't accept any) |
| `nil` / unknown                       | Email-advisor (default)              | Same as student CTA — lower commitment, safer fallback                                            |

The email-advisor modal is currently rendered on the page only inside the AirPods-raffle conditional block (`index.html.erb:61-132`). The new card may need that modal available outside that conditional. **Implementation note**: hoist the modal partial out of the AirPods raffle block so it's always rendered when the new card is shown. Both call sites can share the single `#modal` element.

### Data — who is a "teammate"?

Teammates are other users whose `Event::Affiliation` (where `affiliable_type: "User"`, `name: "first"`) matches the current user's `league` and `team_number`. Both verified and unverified users count.

```ruby
peer_user_ids = Event::Affiliation
  .where(affiliable_type: "User", name: "first")
  .where("metadata ->> 'league' = ?", affiliation.league)
  .where("metadata ->> 'team_number' = ?", affiliation.team_number)
  .where.not(affiliable_id: current_user.id)
  .pluck(:affiliable_id)

@teammates = User.where(id: peer_user_ids)
                 .order(...) # see Sort below
                 .limit(5)
```

### Sort

1. **Verified users first** (verified > unverified)
2. Tiebreak by `User.created_at DESC` (most recently signed up — keeps the social signal feeling fresh)

This is the only sort decision that diverges from Context 1 (org-role ordering doesn't apply when there's no org).

## Hide-when conditions (both contexts)

- The user has no `first` affiliation. (Already an existing edge case — the page handles this today.)
- After excluding self, there are 0 people to display. Show nothing — no fake social proof.

## Visual / component reuse

- Use the existing `.avatar-row` SCSS component (`app/assets/stylesheets/components/_avatars.scss`). It already handles overlapping stack, hover-fan animation, and dark mode.
- Use the existing `avatar_for(user, size: 30)` helper, which handles default-avatar fallback for users without a profile picture.
- Use the existing `.card` class for the new Context 2 card.
- Names rendering: use `to_sentence` (or equivalent) for the comma-and grammar, but on a list of first names only. The "and N others" tail is appended manually when more than 2 teammates exist.

## Out of scope

- Same-league-but-different-team social proof (e.g., "152 FRC people on HCB"). Too generic, weak signal.
- A general "FIRST community" wall in the bottom CTA card. The HCB-staff `avatar-row` there stays untouched.
- Notifications/emails to teammates when someone new signs up.
- Prefilling `/apply` with `league`/`team_number`/`team_name` from the affiliation. Considered, ruled out because the route doesn't currently accept those params and we don't want to expand its surface area as part of this work. Possible future improvement.

## Files expected to change

- `app/controllers/users/first_controller.rb` — load `@team_org_members` (Context 1) and `@teammates` (Context 2) in `index`.
- `app/views/users/first/index.html.erb`
  - Inject avatar-row + names line into the "Request to join" card (Context 1, around line 108-129).
  - Insert new card immediately after line 46 (Context 2).
  - Hoist the email-advisor `#modal` so it's available outside the AirPods conditional.
- Possibly a small partial (e.g. `app/views/users/first/_team_avatar_row.html.erb`) that takes a list of users + a names-line template and renders the shared avatar-stack + sentence. Use only if the duplication between the two contexts feels weighty during implementation; otherwise inline.

## Testing

- Request specs / system specs for `Users::FirstController#index` covering:
  - Team on HCB, with org members → avatars rendered in Request-to-join card; self excluded.
  - Team on HCB, user is sole member → no avatars, card unchanged.
  - Team not on HCB, with teammates → new card rendered; CTA correct for each role.
  - Team not on HCB, no teammates → new card not rendered.
  - User has no `first` affiliation → neither block rendered; page still renders.
  - Names line: 1, 2, 3, and 6+ teammate cases produce correct copy.
  - Sort: verified > unverified; manager > member > reader (Context 1); recency tiebreak.
- No new tests for the email-advisor modal hoisting beyond confirming the modal still opens from its existing trigger.
