# FIRST Home Page — Community / Team Members Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show social-proof avatars (first name + profile picture only) of teammates on the `/first` landing page — folded into the existing "Request to join" card when the user's team org exists, and as a new card below the affiliation when teammates have signed up but the org doesn't exist yet.

**Architecture:** Controller (`Users::FirstController#index`) loads two collections — `@team_org_members` (when an `Event` exists with matching FIRST affiliation) and `@teammates` (other users with the same FIRST affiliation). The view injects an avatar-row + names sentence into the existing Request-to-join card, and renders a new card below the affiliation card when teammates exist but no org does. Role-aware CTA on the new card: students get the email-advisor modal, mentors/coaches get a link to `/apply`.

**Tech Stack:** Rails 7, ERB, RSpec request specs, FactoryBot, existing `.avatar-row` SCSS component, existing `avatar_for` and `User#first_name` helpers.

**Spec:** `docs/superpowers/specs/2026-04-29-first-community-team-members-design.md`

---

## File Structure

**Controller (modify):** `app/controllers/users/first_controller.rb`
- Load `@team_event`, `@team_org_members`, `@teammates` in `index` action.
- Responsibility: data loading only; no view logic.

**View (modify):** `app/views/users/first/index.html.erb`
- Inject avatar-row + names sentence into the existing "Request to join" card.
- Insert a new card immediately after the affiliation card.
- Hoist the email-advisor `#modal` so it's available outside the AirPods-raffle conditional.

**Tests (modify):** `spec/requests/users/first_controller_spec.rb`
- Add `describe "GET /first"` block covering the new behavior. Reuses existing factories.

No new files. No new partials (inline both avatar/sentence blocks since they're rendered in two distinct contexts with different surrounding copy and only ~5 lines of duplication).

---

## Task 1: Controller — load team event, org members, and teammates

**Files:**
- Modify: `app/controllers/users/first_controller.rb` (lines 11–25, the `index` action)

- [ ] **Step 1: Read the current `index` action**

Open `app/controllers/users/first_controller.rb` and confirm lines 11–25 match the spec (the current `index` action loads three raffle ivars and the `@advisor_email_body`). Note the file uses `current_user(allow_unverified: true)` everywhere — match that pattern.

- [ ] **Step 2: Add helper methods at the bottom of the controller**

Add these `private` methods inside the class (below `def user_params`):

```ruby
def load_team_community
  user = current_user(allow_unverified: true)
  affiliation = user&.affiliations&.find_by(name: "first")
  return unless affiliation && affiliation.league.present? && affiliation.team_number.present?

  @first_affiliation = affiliation

  @team_event = Event
    .joins("INNER JOIN event_affiliations ON event_affiliations.affiliable_type = 'Event' AND event_affiliations.affiliable_id = events.id")
    .where(event_affiliations: { name: "first" })
    .where("event_affiliations.metadata ->> 'league' = ?", affiliation.league)
    .where("event_affiliations.metadata ->> 'team_number' = ?", affiliation.team_number)
    .first

  if @team_event
    @team_org_members = @team_event
      .organizer_positions
      .where(deleted_at: nil)
      .where.not(user_id: user.id)
      .joins(:user)
      .order(Arel.sql("users.verified DESC NULLS LAST, organizer_positions.role DESC, organizer_positions.created_at DESC"))
      .limit(5)
      .map(&:user)
    @team_org_members_total = @team_event.organizer_positions.where(deleted_at: nil).where.not(user_id: user.id).count
  else
    peer_user_ids = Event::Affiliation
      .where(affiliable_type: "User", name: "first")
      .where("metadata ->> 'league' = ?", affiliation.league)
      .where("metadata ->> 'team_number' = ?", affiliation.team_number)
      .where.not(affiliable_id: user.id)
      .pluck(:affiliable_id)

    @teammates = User
      .where(id: peer_user_ids)
      .order(Arel.sql("verified DESC NULLS LAST, created_at DESC"))
      .limit(5)
      .to_a
    @teammates_total = peer_user_ids.size
  end
end
```

- [ ] **Step 3: Call the helper from `index`**

In the `index` action (line 11), add `load_team_community` immediately before the line that loads `@macbook_raffle`. Result:

```ruby
def index
  return redirect_to welcome_first_index_path unless signed_in?(allow_unverified: true)

  load_team_community

  @macbook_raffle = Raffle.find_by(user: current_user(allow_unverified: true), program: "first-worlds-2026-macbook")
  @printer_raffle = Raffle.find_by(user: current_user(allow_unverified: true), program: "first-worlds-2026-printer")
  @airpods_raffle = Raffle.find_by(user: current_user(allow_unverified: true), program: "first-worlds-2026-airpods")

  @advisor_email_body = <<~EMAIL
    ...
  EMAIL
end
```

- [ ] **Step 4: Sanity-check by booting the server**

Run: `bin/rails runner 'Users::FirstController.instance_method(:load_team_community)'`
Expected: prints `#<UnboundMethod: ...>` with no error. Confirms the method parses.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/users/first_controller.rb
git commit -m "[FIRST] Load team org members and teammates for community block"
```

---

## Task 2: View — hoist the email-advisor modal out of the AirPods-raffle conditional

**Files:**
- Modify: `app/views/users/first/index.html.erb`

The existing `#modal` block lives at lines 226–244, inside the same `<% end %>` chain as the AirPods raffle conditional. Visually it's outside the conditional today (it's at the bottom of the file), but verify it's still rendered when the AirPods criteria don't apply — if so this task is a no-op.

- [ ] **Step 1: Verify modal placement**

Read `app/views/users/first/index.html.erb`. Trace the `<% end %>` tags. Confirm: is the `<section id="modal">` at line 226 inside any of the `<% if ... %>` blocks at lines 23, 48, 52, 56, 61, 62, 63, 86, 87?

- If the modal is OUTSIDE all conditionals (always rendered): no change needed — proceed to Step 4.
- If the modal is INSIDE the AirPods-raffle conditional: move it to the very end of the file, after the last `<% end %>` of the AirPods block, but before any closing tags or the `<%# ... %>` comment.

- [ ] **Step 2: If modal needs hoisting, move it**

Cut the entire `<section id="modal" ...>` ... `</section>` block (lines 226–244) and paste it at the end of the file, ensuring it's outside every `<% if %>` block. Confirm no ERB syntax errors by running:

```bash
bundle exec erb_lint --lint-all app/views/users/first/index.html.erb
```

Expected: no errors.

- [ ] **Step 3: Verify modal is rendered when AirPods raffle is not eligible**

Run: `bin/rails runner 'puts ApplicationController.render(template: "users/first/index", assigns: { current_user: User.first }).include?(\"id=\\\"modal\\\"\") rescue puts $!'`

This won't actually work without a full session, so instead just visually grep:

```bash
grep -n 'id="modal"\|<% end %>' app/views/users/first/index.html.erb | tail -20
```

Confirm `id="modal"` is the last (or near-last) line and not nested inside any unclosed `<% if %>`.

- [ ] **Step 4: Commit (if changes were made; otherwise skip)**

```bash
git add app/views/users/first/index.html.erb
git commit -m "[FIRST] Hoist email-advisor modal so it's always rendered on /first"
```

---

## Task 3: View — inject Context 1 avatar block into the "Request to join" card

**Files:**
- Modify: `app/views/users/first/index.html.erb` (lines 108–129, the "Request to join" card)

The existing card body (line 117–120) currently reads:

```erb
<p class="my-0 md:my-2">
  Good news&mdash;<strong><%= affiliation.team_name.presence || "your team" %></strong> (<%= affiliation.league&.upcase %> #<%= affiliation.team_number %>) is already running on HCB!
  Request to join their organization, and once you're approved we'll automatically sign you up for our 3D printer raffle for a chance to win a free Bambu Lab A1.
</p>
```

We add an avatar-row + names sentence directly below this `<p>`, before the `<div class="mb-6 mt-4">` that wraps the disabled button at line 121.

- [ ] **Step 1: Insert the avatar block**

After the closing `</p>` of the body paragraph (line 120) and before line 121's `<div class="mb-6 mt-4">`, insert:

```erb
<% if @team_org_members.present? %>
  <div class="flex flex-row items-center gap-3 mt-4">
    <div class="avatar-row">
      <% @team_org_members.each do |member| %>
        <%= avatar_for member, size: 30 %>
      <% end %>
    </div>
    <p class="my-0 text-sm muted">
      <%
        names = @team_org_members.map { |u| u.first_name.presence || u.full_name.to_s.split(" ").first || "Someone" }
        leftover = @team_org_members_total - @team_org_members.size
        sentence = case @team_org_members.size
                   when 1
                     leftover.zero? ? "#{names[0]} is on this team" : "#{names[0]} and #{pluralize(leftover, 'other')} are on this team"
                   when 2
                     leftover.zero? ? "#{names[0]} and #{names[1]} are on this team" : "#{names[0]}, #{names[1]}, and #{pluralize(leftover, 'other')} are on this team"
                   else
                     extras = leftover + (@team_org_members.size - 2)
                     "#{names[0]}, #{names[1]}, and #{pluralize(extras, 'other')} are on this team"
                   end
      %>
      <%= sentence %>
    </p>
  </div>
<% end %>
```

- [ ] **Step 2: Lint**

Run: `bundle exec erb_lint --lint-all app/views/users/first/index.html.erb`
Expected: no errors.

- [ ] **Step 3: Spin up the dev server and visually verify (optional smoke test)**

Run: `bin/dev` (or whatever the project uses; check `Procfile.dev` or `bin/`). Sign in as a user whose team has multiple organizer_positions (use Rails console to set up if needed) and visit `/first`. Confirm the avatar row appears in the Request-to-join card.

If you can't easily set up the data, skip — the request spec in Task 5 will cover correctness.

- [ ] **Step 4: Commit**

```bash
git add app/views/users/first/index.html.erb
git commit -m "[FIRST] Show teammate avatars in the Request to join card"
```

---

## Task 4: View — add Context 2 card below the affiliation card

**Files:**
- Modify: `app/views/users/first/index.html.erb` (insert after line 46, immediately after the affiliation card)

This card renders only when `@team_event` is nil AND `@teammates` is non-empty. It uses the standard `.card` class (white) and a role-aware CTA.

- [ ] **Step 1: Insert the new card after the affiliation card**

Immediately after line 46 (the closing `<% end %>` of the affiliation card block) and before line 48 (the `@macbook_raffle` block), insert:

```erb
<% if @team_event.nil? && @teammates.present? %>
  <div class="card my-4">
    <div class="flex flex-row items-center gap-3 mb-3">
      <div class="avatar-row">
        <% @teammates.each do |teammate| %>
          <%= avatar_for teammate, size: 30 %>
        <% end %>
      </div>
      <h3 class="heading my-0">Your teammates are on HCB</h3>
    </div>

    <p class="my-2">
      <%
        names = @teammates.map { |u| u.first_name.presence || u.full_name.to_s.split(" ").first || "Someone" }
        leftover = @teammates_total - @teammates.size
        team_label = "#{@first_affiliation.league&.upcase} ##{@first_affiliation.team_number}"
        sentence = case @teammates.size
                   when 1
                     leftover.zero? ? "#{names[0]} from #{team_label} has signed up for HCB" : "#{names[0]} and #{pluralize(leftover, 'other')} from #{team_label} have signed up for HCB"
                   when 2
                     leftover.zero? ? "#{names[0]} and #{names[1]} from #{team_label} have signed up for HCB" : "#{names[0]}, #{names[1]}, and #{pluralize(leftover, 'other')} from #{team_label} have signed up for HCB"
                   else
                     extras = leftover + (@teammates.size - 2)
                     "#{names[0]}, #{names[1]}, and #{pluralize(extras, 'other')} from #{team_label} have signed up for HCB"
                   end
      %>
      <%= sentence %>. Get your team's organization set up to fundraise and spend together.
    </p>

    <% role = @first_affiliation.role %>
    <% if ["head_coach", "mentor_advisor"].include?(role) %>
      <%= link_to "Start your team's organization →", apply_path, class: "btn" %>
    <% else %>
      <%= link_to "#", class: "btn", "data-behavior": "modal_trigger", "data-modal": "modal" do %>
        Email your advisor about HCB →
      <% end %>
    <% end %>
  </div>
<% end %>
```

- [ ] **Step 2: Confirm the route helper exists**

Run: `bin/rails routes | grep -E '\sapply\s'`
Expected: a row showing `apply` mapped to `/apply` and the helper `apply_path`.

If the helper is not `apply_path`, use the correct one (likely `apply_applications_path` if it's nested under `applications` resources). Verify by inspecting `config/routes.rb:866`. Pre-check: line 866 is `get "apply", to: "applications#apply"` — confirm whether it's at the top level or inside a namespace, and use the matching helper.

- [ ] **Step 3: Lint**

Run: `bundle exec erb_lint --lint-all app/views/users/first/index.html.erb`
Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add app/views/users/first/index.html.erb
git commit -m "[FIRST] Add teammate community card when team org doesn't exist"
```

---

## Task 5: Tests — request specs covering both contexts

**Files:**
- Modify: `spec/requests/users/first_controller_spec.rb`

We add a `describe "GET /first"` block. The existing spec already covers `POST /first` and `DELETE /first/sign_out`; we're adding alongside, not modifying.

For sign-in: the existing test fixture pattern uses `create(:user, verified: true)`. The controller permits unverified users (`allow_unverified: true`), so we'll sign in via the project's existing auth helper. Look at how other request specs sign users in (search for `sign_in` or session setup in `spec/support/`).

- [ ] **Step 1: Find the project's request-spec sign-in pattern**

Run: `grep -rn 'def sign_in\|sign_in_as\|sign_in user' spec/support/ spec/requests/ 2>/dev/null | head -10`

Note the helper name and how it's used. If no helper exists and existing request specs sign in by hitting `/users/auth/login` flows, prefer creating the user + writing the session cookie directly. Use whatever pattern is already established.

- [ ] **Step 2: Add a `describe "GET /first"` block at the bottom of the file**

Append this inside the top-level `RSpec.describe` block, before the final `end`:

```ruby
describe "GET /first" do
  let(:user) { create(:user, verified: true) }
  let(:affiliation_metadata) { { "league" => "frc", "team_number" => "9999" } }

  before do
    user.affiliations.create!(name: "first", metadata: affiliation_metadata.merge("role" => "student_member"))
    sign_in user # adjust to project's helper
  end

  context "when the team org exists on HCB" do
    let!(:team_event) { create(:event) }
    let!(:event_affiliation) do
      Event::Affiliation.create!(affiliable: team_event, name: "first", metadata: affiliation_metadata)
    end
    let!(:teammate_user) { create(:user, verified: true, full_name: "Maya Patel") }
    let!(:teammate_position) { create(:organizer_position, user: teammate_user, event: team_event) }

    it "renders the teammate avatar inside the Request to join card" do
      get "/first"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Maya")
      expect(response.body).to include("on this team")
    end

    it "excludes the current user from the avatar row" do
      create(:organizer_position, user: user, event: team_event)
      get "/first"
      # Self-membership means the user IS in the org, so they see the printer-raffle branch instead.
      # The Request-to-join card is not rendered. Either way, the user's own first name should not appear in any avatar-row context.
      expect(response.body).not_to match(/avatar-row[^<]*<img[^>]*alt="#{user.first_name}"/i)
    end
  end

  context "when the team org does not exist but teammates have signed up" do
    let!(:teammate1) { create(:user, verified: true, full_name: "Maya Patel") }
    let!(:teammate2) { create(:user, verified: false, full_name: "Eli Chen") }

    before do
      teammate1.affiliations.create!(name: "first", metadata: affiliation_metadata)
      teammate2.affiliations.create!(name: "first", metadata: affiliation_metadata)
    end

    it "renders the new community card with the teammate names" do
      get "/first"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Your teammates are on HCB")
      expect(response.body).to include("Maya")
      expect(response.body).to include("Eli")
      expect(response.body).to include("FRC #9999")
    end

    it "shows the email-advisor CTA for student roles" do
      get "/first"
      expect(response.body).to include("Email your advisor about HCB")
    end

    it "shows the start-organization CTA for mentor/coach roles" do
      user.affiliations.first.update!(metadata: affiliation_metadata.merge("role" => "head_coach"))
      get "/first"
      expect(response.body).to include("Start your team's organization")
      expect(response.body).not_to include("Email your advisor about HCB →") # CTA-specific copy with arrow
    end
  end

  context "when no teammates have signed up" do
    it "does not render the community card" do
      get "/first"
      expect(response.body).not_to include("Your teammates are on HCB")
    end
  end

  context "when the user has no FIRST affiliation" do
    before { user.affiliations.destroy_all }

    it "renders the page without a community card" do
      get "/first"
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Your teammates are on HCB")
    end
  end
end
```

Note: `sign_in user` is a placeholder. Replace with the project's actual helper (per Step 1).

- [ ] **Step 3: Run the new tests**

Run: `bundle exec rspec spec/requests/users/first_controller_spec.rb -e "GET /first"`

Expected: all five examples pass.

If any test fails because the sign-in helper isn't right, adjust per Step 1's findings. If the data setup misses something (e.g., affiliation factory missing, event factory needing specific traits), adjust based on the actual factory definitions in `spec/factories/`.

- [ ] **Step 4: Run the full file to confirm no regressions**

Run: `bundle exec rspec spec/requests/users/first_controller_spec.rb`

Expected: all examples pass (existing 3 + new 5).

- [ ] **Step 5: Commit**

```bash
git add spec/requests/users/first_controller_spec.rb
git commit -m "[FIRST] Test team-community block on /first"
```

---

## Task 6: Lint pass and final verification

- [ ] **Step 1: Run lint with auto-correct**

Run: `bin/lint -C`

Auto-corrects Ruby/SCSS/ERB style. Re-run tests after if any files were changed:

```bash
bundle exec rspec spec/requests/users/first_controller_spec.rb
```

- [ ] **Step 2: If lint made changes, commit**

```bash
git status
# if changes:
git add -u
git commit -m "[FIRST] Lint fixes for community block"
```

- [ ] **Step 3: Visual smoke test**

Start the dev server, sign in as a user with a FIRST affiliation, and visit `/first`. Run through:

1. User with team on HCB and teammates → avatar row appears in Request-to-join card.
2. User with team NOT on HCB and ≥1 teammate → new community card appears below affiliation card with role-aware CTA.
3. User with no teammates and no team org → neither block appears, rest of page intact.

Use Rails console to manipulate data as needed.

If visual issues (overflow, layout breaks at small viewports), fix them inline and commit.

---

## Self-Review

Spec coverage check: ✓ Context 1 in Task 3, ✓ Context 2 in Task 4, ✓ role-aware CTA in Task 4, ✓ verified-first sort in Task 1, ✓ org-role sort in Task 1, ✓ self-exclusion in Task 1, ✓ hide-when-no-data in Tasks 3 & 4 (`if @team_org_members.present?` / `if @team_event.nil? && @teammates.present?`), ✓ first-name-only display in Tasks 3 & 4 (uses `User#first_name`), ✓ modal hoisting in Task 2, ✓ tests in Task 5.

Type/name consistency check: `@team_event`, `@team_org_members`, `@team_org_members_total`, `@teammates`, `@teammates_total`, `@first_affiliation` — names used in controller match names used in views. `apply_path` flagged for verification in Task 4 Step 2.
