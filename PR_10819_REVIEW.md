# Review: PR #10819 — [Donation tiers] Improve functionality

## Summary

This PR adds publish/unpublish functionality for donation tiers, extracts shared controller logic into a `DonationPageSetup` concern, introduces a dedicated `TierPolicy`, adds model validations (10-tier limit, amount divisible by 100), and improves the settings UI with auto-save via a Stimulus controller.

---

## Bugs (Critical)

### 1. Missing `@hide_flash` in `DonationsController#start_donation`

**File:** `app/controllers/donations_controller.rb:49-53`

The old `start_donation` set `@hide_flash = true`. After the refactor, `build_donation_page!` does NOT set it, and the new `start_donation` doesn't either. The `TiersController#start` correctly sets `@hide_flash = true`, but `DonationsController#start_donation` lost it. Flash messages will now inappropriately display on the donation page when accessed through the non-tier route.

**Fix:** Add `@hide_flash = true` either inside `build_donation_page!` or in `DonationsController#start_donation` after the `build_donation_page!` call.

### 2. `not_found` return value may not short-circuit in `DonationsController`

**File:** `app/controllers/concerns/donation_page_setup.rb:7-9` and `app/controllers/donations_controller.rb:49`

```ruby
# In DonationPageSetup:
unless event.donation_page_available?
  return not_found
end

# In DonationsController:
return unless build_donation_page!(event: @event, params:, request:)
```

If `not_found` returns a truthy value (which most Rails not-found implementations do), `build_donation_page!` returns truthy, the `unless` guard does NOT trigger, and execution continues to `authorize @donation` where `@donation` is nil, causing a `NoMethodError`.

**Fix:** Return `false` explicitly after `not_found`:
```ruby
unless event.donation_page_available?
  not_found
  return false
end
```

### 3. `update` action crashes on missing tier (`NoMethodError` on `nil`)

**File:** `app/controllers/donation/tiers_controller.rb:70-74`

```ruby
params[:tiers]&.each_key do |id|
  tier = @event.donation_tiers.find_by(id: id)
  authorize tier, :update?   # <-- tier could be nil here
  tiers << tier
end
```

If `find_by` returns `nil` (e.g., tier was deleted or doesn't belong to this event), calling `authorize nil, :update?` raises `NoMethodError`. The old code had `next unless tier` to handle this.

**Fix:** Re-add the nil guard:
```ruby
params[:tiers]&.each_key do |id|
  tier = @event.donation_tiers.find_by(id: id)
  next unless tier
  authorize tier, :update?
  tiers << tier
end
```

### 4. `donation_page?` policy skips `financially_frozen?` check

**File:** `app/policies/event_policy.rb` (new method)

```ruby
def donation_page?
  record.approved? && record.plan.donations_enabled? && record.donation_page_enabled?
end
```

Compare with `donation_page_available?` on the Event model:
```ruby
def donation_page_available?
  donation_page_enabled && plan.donations_enabled? && !financially_frozen?
end
```

The policy method doesn't check `!financially_frozen?`. A financially frozen organization's tier donation page will remain accessible via `TiersController#start`. The original `DonationPolicy#start_donation?` correctly delegates to `donation_page_available?` which includes the freeze check.

**Fix:**
```ruby
def donation_page?
  record.donation_page_available?
end
```

---

## Security Issues

### 5. Privilege escalation: `TierPolicy` delegates to `edit?` instead of `update?`

**File:** `app/policies/donation/tier_policy.rb:4`

```ruby
def can_update_event?
  EventPolicy.new(user, record.event).edit?
end
```

`EventPolicy#edit?` checks `auditor_or_member?` (any member or auditor).
`EventPolicy#update?` checks `admin_or_manager?` (only managers and admins).

The old code used `authorize @event, :update?` — only managers/admins could modify tiers. The new policy delegates to `edit?`, meaning ANY member (including readers) can now create, update, delete, and reorder tiers. This is a significant privilege escalation.

**Fix:** Change to delegate to `update?`:
```ruby
def can_update_event?
  EventPolicy.new(user, record.event).update?
end
```

### 6. No strong params on tier update

**File:** `app/controllers/donation/tiers_controller.rb:77-82`

The controller accesses `params[:tiers][tier.id.to_s]` directly without `permit`. While the fields used are explicitly selected (`name`, `description`, `amount_cents`, `published`), Rails best practice is to use strong params for defense in depth.

---

## Edge Cases

### 7. `amount_divisible_by_100` breaks editing existing tiers

**File:** `app/models/donation/tier.rb`

The new validation `amount_cents % 100 != 0` runs on ALL saves. Existing tiers with non-round amounts (e.g., $9.99 = 999 cents, $4.50 = 450 cents) will now fail validation when any field is updated — even if the amount isn't being changed.

**Fix:** Only validate on create or when amount_cents changes:
```ruby
def amount_divisible_by_100
  return unless amount_cents_changed?
  if amount_cents.present? && amount_cents % 100 != 0
    errors.add(:amount_cents, "must be divisible by 100")
  end
end
```

### 8. Unpublished tiers count toward the 10-tier limit

**File:** `app/models/donation/tier.rb`

The `maximum_tiers_limit` validation counts all tiers (published + unpublished). A user could have only 3 published tiers but be blocked from creating more because they have 7 unpublished drafts. This might be intentional but should be documented or reconsidered.

### 9. Direct URL access to tiers works even when `donation_tiers_enabled` is false

**File:** `app/controllers/concerns/donation_page_setup.rb:12-19`

`build_donation_page!` looks up tiers by `published: true` but never checks `event.donation_tiers_enabled?` before the lookup. If someone has a saved URL `/donations/start/my-event/tiers/123`, it will load the tier and set `@tier` even if tiers are disabled for that event. `@show_tiers` will be false, but `@tier` and `@monthly` will still be set.

### 10. `set_index` doesn't scope tier lookup to any event

**File:** `app/controllers/donation/tiers_controller.rb:14`

```ruby
tier = Donation::Tier.find_by(id: params[:id])
```

This finds tiers globally. While the policy check prevents unauthorized access, it means a user managing multiple events could potentially pass a tier ID from event A while intending to reorder event B. The `before_action :set_event` is excluded for this action.

---

## Code Quality

### 11. Missing `disconnect()` cleanup in Stimulus controller

**File:** `app/javascript/controllers/donation_tier_form_controller.js`

Event listeners added in `connect()` are never removed in `disconnect()`. This causes memory leaks during Turbo navigation or DOM updates.

### 12. Checkbox logic split between Stimulus controller and inline handler

The Stimulus controller only shows a loader on checkbox change, while the actual form submission is handled by an inline `onchange` attribute. The logic should be consolidated in one place.

### 13. Double blank lines before `end`

**Files:** `app/policies/donation/tier_policy.rb`, `app/models/donation/tier.rb` — minor style inconsistency.

---

## Missing Test Coverage

There are **zero tests** for donation tiers in the spec directory. The following should be added:

1. **Model specs:** `maximum_tiers_limit`, `amount_divisible_by_100`, `published` default
2. **Policy specs:** `TierPolicy` delegation behavior
3. **Controller specs:** `TiersController#start`, `#create`, `#update`, `#destroy`
4. **Concern specs:** `DonationPageSetup#build_donation_page!` edge cases
5. **Integration/system tests:** Full donation tier selection flow
6. **Migration spec:** Verify existing tiers set to `published: true`

---

## Verdict

The PR has several bugs that would cause runtime errors in production (nil tier crash, potential `not_found` passthrough) and a significant authorization regression (privilege escalation from `update?` to `edit?`). These should be fixed before merging. The `financially_frozen?` bypass and the `@hide_flash` regression are lower priority but should also be addressed. The lack of test coverage for this feature is concerning given its complexity.
