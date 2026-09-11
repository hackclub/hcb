# frozen_string_literal: true

class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    false
  end

  def show?
    false
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    false
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  # Attribute-level authorization.
  #
  # Returns the API field names (not necessarily model attributes — see below)
  # that this user may see on this record. Serializers are DENY BY DEFAULT: a
  # field absent from this list is never emitted, so forgetting to list a field
  # is a missing-data bug rather than a data leak.
  #
  # Names are keys in the *output contract*, so a derived value is listed under
  # the name it ships as (`:account_number_last4`, not `:account_number`).
  #
  # This is deliberately NOT Pundit's `permitted_attributes`, which is already
  # used in this codebase for strong-parameter *input* (see SponsorPolicy).
  # Read and write lists differ and must not share a method.
  def visible_attributes
    []
  end

  def visible?(attribute)
    visible_attributes.include?(attribute)
  end

  # Object-level authorization for read routes, derived from the field lattice
  # rather than restated next to it: if there is not a single attribute this
  # user may see, there is nothing to serve.
  #
  # This is what replaces the `*_in_v4?` family. Those methods exist only
  # because v4 restated `show?` without its transparency clause; deriving the
  # read gate from `visible_attributes` means a new API surface changes which
  # fields it asks for, never which policy method it calls.
  def show_any_attribute?
    visible_attributes.any?
  end

  # ---- Shared tier helpers -------------------------------------------------
  #
  # Almost every record hangs off an organization, and the transparency tier
  # asks the same question each time. Defining it once means a new policy gets
  # the N+1-safe role check by default rather than reaching for
  # `OrganizerPosition.role_at_least?`, which queries per record — and a policy
  # consulted while rendering a list is consulted once per row.
  #
  # These are deliberately named `event_*` rather than `reader?`/`manager?`,
  # which several policies already define with their own meaning.

  # The organization this record's access hangs off. Override where a record
  # reaches its event by another path (a card grant, a sponsor, a parent).
  def policy_event
    record.try(:event)
  end

  # The v3 transparency tier: a transparent organization's records are readable
  # by anyone, signed in or not.
  def transparent_or_reader?
    !!policy_event&.is_public? || !!user&.auditor? || event_reader?
  end

  # Equivalent to OrganizerPosition.role_at_least?(user, policy_event, :reader),
  # resolved from a set memoized on the user. See
  # spec/policies/ach_transfer_policy_spec.rb, which asserts the equivalence
  # across an organization hierarchy for every role.
  def event_reader?
    event = policy_event
    return false if user.nil? || event.nil?

    user.readable_event_ids.include?(event.id)
  end

  # As #event_reader?, for manager-or-better.
  def event_manager?
    event = policy_event
    return false if user.nil? || event.nil?

    user.manageable_event_ids.include?(event.id)
  end

  def scope
    Pundit.policy_scope!(user, record.class)
  end

  class Scope
    attr_reader :user, :scope

    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    # Deny by default, mirroring #visible_attributes: a policy that hasn't
    # defined a Scope resolves to nothing rather than everything, so forgetting
    # one produces an empty index (loud, harmless) instead of exposing every
    # row (silent, not).
    def resolve
      scope.none
    end

  end

end
