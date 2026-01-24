# Code Review: PR #11477 - [Ledger] Multiple filters

## Overview
This PR implements multi-select filtering for the ledger view, allowing users to select multiple transaction types and users simultaneously. While the feature is valuable, there are several critical issues and concerns that need to be addressed.

---

## 🔴 Critical Issues

### 1. **Logic Bug: AND vs OR for Type Filters**
**Location:** `app/controllers/events_controller.rb:1003-1009`

**Issue:** The current implementation has contradictory logic:

```ruby
if type.present?
  types = Array(type)
  types.each do |t|
    filter = type_filters[t]
    next unless filter
    settled_transactions = settled_transactions.select(&filter["settled"])
    pending_transactions = pending_transactions.select(&filter["pending"])
  end
end
```

**Problem:** This creates AND logic - it chains multiple `.select()` calls, meaning a transaction must match ALL selected types. However, a transaction can only be ONE type (e.g., "card_charge" OR "ach_transfer", never both). This means selecting multiple types would return ZERO results.

**Expected Behavior:** Should use OR logic - show transactions matching ANY of the selected types.

**Recommendation:**
```ruby
if type.present?
  types = Array(type)
  type_filters_array = types.map { |t| type_filters[t] }.compact

  if type_filters_array.any?
    settled_transactions = settled_transactions.select do |t|
      type_filters_array.any? { |filter| filter["settled"].call(t) }
    end
    pending_transactions = pending_transactions.select do |t|
      type_filters_array.any? { |filter| filter["pending"].call(t) }
    end
  end
end
```

**Severity:** HIGH - Core functionality is broken
**Reviewer Note:** David Cornu flagged this exact concern in the PR comments

---

### 2. **SQL Injection Risk in User Filter**
**Location:** `app/services/pending_transaction_engine/pending_transaction/all.rb:80-81`

**Current Code:**
```ruby
if @user
  user_ids = Array(@user).map { |u| u.respond_to?(:stripe_cardholder) ? u.stripe_cardholder&.stripe_id : u }
  cpts = cpts.where("raw_pending_stripe_transactions.stripe_transaction->>'cardholder' IN (?)", user_ids)
```

**Issue:** If `u` is a raw string (not an object), it could be passed directly to the SQL query without sanitization. The `respond_to?(:stripe_cardholder)` check doesn't guarantee `u` is safe to use.

**Recommendation:** Add validation to ensure all IDs are sanitized:
```ruby
if @user.present?
  user_ids = Array(@user).map do |u|
    u.respond_to?(:stripe_cardholder) ? u.stripe_cardholder&.stripe_id : u
  end.compact

  # Ensure all IDs are strings and not malicious input
  user_ids.reject! { |id| id.blank? || !id.is_a?(String) }

  if user_ids.any?
    cpts = cpts.where("raw_pending_stripe_transactions.stripe_transaction->>'cardholder' IN (?)", user_ids)
  end
end
```

**Severity:** HIGH - Potential security vulnerability

---

## ⚠️ Major Issues

### 3. **Inconsistent Variable Naming**
**Locations:** Multiple files

**Issue:** The code mixes singular and plural variable names inconsistently:
- Controller sets `@user` and `@type` (singular based on current code)
- Views expect arrays and use `Array(@user)` and `Array(@type)`
- Services expect arrays but check with `.present?` and `.all?`

**Current State (events_controller.rb:1185-1187):**
```ruby
@user = @event.users.friendly.find(params[:user], allow_nil: true) if params[:user]
@type = params[:type]
```

**PR Changes (from diff):**
```ruby
@users = if params[:user].present?
  Array(params[:user]).map { |u| @event.users.friendly.find(u, allow_nil: true) }.compact
end
@types = params[:type]
```

**Problem:** If the controller sets `@users` and `@types` (plural), but the service classes still reference `@user` (singular), there will be nil reference errors.

**Recommendation:**
1. Consistently use plural names everywhere: `@users`, `@types`
2. Update ALL references across all files
3. Always initialize as arrays (even if empty): `@users ||= []`, `@types ||= []`

**Severity:** MEDIUM - Code will fail at runtime

---

### 4. **Missing Type Safety in Transaction Grouping**
**Location:** `app/services/transaction_grouping_engine/transaction/all.rb:107-111`

**Current Code:**
```ruby
def user_modifier
  return "" unless @user.present? && @user.all? { |u| u&.stripe_cardholder&.stripe_id.present? }
  stripe_ids = @user.map { |u| u.stripe_cardholder.stripe_id }
  ActiveRecord::Base.sanitize_sql_array(["and raw_stripe_transactions.stripe_transaction->>'cardholder' IN (?)", stripe_ids])
end
```

**Issue:**
- `.all?` method only works on arrays/enumerables
- If `@user` is `nil`, `.present?` returns `false` ✓
- If `@user` is a single User object (not array), `.all?` will fail ✗

**Recommendation:**
```ruby
def user_modifier
  users = Array(@user).compact
  return "" if users.empty? || users.any? { |u| u.stripe_cardholder&.stripe_id.blank? }

  stripe_ids = users.map { |u| u.stripe_cardholder.stripe_id }
  ActiveRecord::Base.sanitize_sql_array([
    "and raw_stripe_transactions.stripe_transaction->>'cardholder' IN (?)",
    stripe_ids
  ])
end
```

**Severity:** MEDIUM - Runtime errors possible

---

### 5. **Complex `upsert_query_params` Logic**
**Location:** `app/helpers/application_helper.rb:6-8` (old) vs new implementation

**New Implementation:**
```ruby
def upsert_query_params(**new_params)
  params_hash = (request.query_parameters || {}).deep_dup.stringify_keys
  new_params.each do |raw_key, value|
    key = raw_key.to_s
    case value
    when nil
      params_hash.delete(key)
    when Array
      params_hash[key] = value.compact
    when Hash
      current = Array(params_hash[key])
      if value.key?(:remove)
        current -= Array(value[:remove]).compact
      end
      if value.key?(:add)
        Array(value[:add]).compact.each do |v|
          current << v unless current.include?(v)
        end
      end
      current.empty? ? params_hash.delete(key) : params_hash[key] = current
    else
      params_hash[key] = value
    end
  end
  params_hash
end
```

**Issues:**
1. **Overly complex** - handles nested hashes with `:add` and `:remove` keys
2. **No documentation** - unclear how to use the Hash form
3. **Type coercion** - `Array(params_hash[key])` wraps single values, but Rails params might already be arrays
4. **Edge case:** What if someone passes `{ add: nil }` or `{ remove: [] }`?

**Recommendation:**
1. Add comprehensive documentation with examples
2. Add unit tests for edge cases
3. Consider splitting into separate methods for clarity:
   ```ruby
   def add_to_param(key, values)
   def remove_from_param(key, values)
   ```

**Severity:** MEDIUM - Maintainability concern

---

## 💡 Minor Issues & Suggestions

### 6. **Inconsistent Nil Handling**
**Location:** `app/views/events/_filter_menu.html.erb:55`

**Code:**
```erb
<%= link_to(event_ledger_path(@event, upsert_query_params(page: 1,
        type: { (@type.include?(type) ? :remove : :add) => type })),
        class: "flex-auto menu__action #{"menu__action--active" if @type.include?(type)}",
```

**Issue:** If `@type` is `nil`, `.include?` will fail with NoMethodError

**Fix:**
```erb
<% types = Array(@type) %>
<%= link_to(event_ledger_path(@event, upsert_query_params(page: 1,
        type: { (types.include?(type) ? :remove : :add) => type })),
        class: "flex-auto menu__action #{"menu__action--active" if types.include?(type)}",
```

---

### 7. **DRY Violation in View**
**Location:** `app/views/events/_filter.html.erb`

**Issue:** The humanize logic is duplicated:
```erb
<%= @type.humanize.gsub("Ach", "ACH").gsub("Paypal", "PayPal").gsub("Hcb", "HCB") %>
```

Appears in both `_filter.html.erb` and `_filter_menu.html.erb`

**Recommendation:** Extract to helper method:
```ruby
def humanize_transaction_type(type)
  type.to_s.humanize.gsub("Ach", "ACH").gsub("Paypal", "PayPal").gsub("Hcb", "HCB")
end
```

---

### 8. **Missing Validation in Controller**
**Location:** `app/controllers/events_controller.rb:1185`

**New Code:**
```ruby
@users = if params[:user].present?
  Array(params[:user]).map { |u| @event.users.friendly.find(u, allow_nil: true) }.compact
end
```

**Issue:** If a user passes an invalid ID, `.find()` with `allow_nil: true` returns `nil`, which gets compacted out. This silently fails - the user doesn't know their filter was invalid.

**Recommendation:** Log or notify when invalid filters are provided:
```ruby
@users = if params[:user].present?
  user_params = Array(params[:user])
  found_users = user_params.map { |u| @event.users.friendly.find(u, allow_nil: true) }.compact

  if found_users.size != user_params.size
    Rails.logger.warn("Some user IDs not found: #{user_params - found_users.map(&:id)}")
  end

  found_users
end
```

---

## 🧪 Testing Recommendations

### Required Test Cases:
1. **Multiple type filters with OR logic**
   - Select "card_charge" and "ach_transfer"
   - Verify both types appear in results
   - Verify transactions are not duplicated

2. **Multiple user filters**
   - Select 2+ users
   - Verify transactions from all selected users appear

3. **Edge cases:**
   - Select all types → should show all transactions
   - Toggle a filter on and off → should add/remove correctly
   - Select invalid user ID → should handle gracefully
   - Mix of pending and settled transactions with type filters

4. **SQL injection attempts:**
   - Pass malicious strings as user IDs
   - Verify queries are properly sanitized

5. **Performance:**
   - Test with 100+ transactions and multiple filters
   - Verify query performance doesn't degrade

---

## 📝 Documentation Needs

1. **Update README/docs** - Explain multi-select filter behavior
2. **Add inline comments** - Especially in `upsert_query_params`
3. **Document OR vs AND** - Clarify that multiple types use OR logic (once fixed)

---

## ✅ Positive Aspects

1. **Good UX improvement** - Multi-select is a valuable feature
2. **Consistent UI patterns** - Badge removal UI is intuitive
3. **SQL sanitization** - Uses `sanitize_sql_array` correctly (with noted exception)
4. **Backward compatibility** - `Array()` wrapper allows single values to still work

---

## 🎯 Recommendation

**DO NOT MERGE** until the following are addressed:

### Must Fix (Blocking):
1. ✋ Fix AND/OR logic bug in type filters
2. ✋ Ensure all variable names are consistent (`@user` vs `@users`)
3. ✋ Add nil checks in `_filter_menu.html.erb`
4. ✋ Fix type safety in `user_modifier` method

### Should Fix (Strongly Recommended):
5. 🔧 Add input validation/sanitization in user filter queries
6. 🔧 Add comprehensive test coverage
7. 🔧 Document `upsert_query_params` usage

### Nice to Have:
8. 💡 Extract `humanize_transaction_type` helper
9. 💡 Add logging for invalid filter IDs
10. 💡 Simplify `upsert_query_params` or split into smaller methods

---

## Estimated Effort to Fix
- Critical issues: 2-3 hours
- Testing: 2-4 hours
- Documentation: 1 hour
- **Total: ~6-8 hours**

---

**Reviewed by:** Claude Code
**Date:** 2026-01-24
**PR:** #11477
