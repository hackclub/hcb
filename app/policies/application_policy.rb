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

  def scope
    Pundit.policy_scope!(user, record.class)
  end

  class Scope
    attr_reader :user, :scope

    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      scope
    end

  end

end
