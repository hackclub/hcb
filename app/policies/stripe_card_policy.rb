# frozen_string_literal: true

class StripeCardPolicy < ApplicationPolicy
  # Cards follow their organization's visibility — v3 publishes a transparent
  # organization's cards — plus the cardholder's own, which they can see
  # wherever it was issued.
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all if user&.auditor?

      visible = scope.where(event: Event.visible_to(user))
      return visible if user.nil?

      visible.or(scope.where(stripe_cardholder: StripeCardholder.where(user:)))
    end

  end

  def index?
    user&.auditor?
  end

  def shipping?
    user&.auditor? || OrganizerPosition.role_at_least?(user, record.event, :reader)
  end

  def freeze?
    admin_or_manager? || member_and_cardholder? || grantee?
  end

  def defrost?
    return false if record.event&.financially_frozen?
    return false if record.last_frozen_by.present? && record.last_frozen_by != user && !admin_or_manager?

    freeze?
  end

  def cancel?
    admin_or_manager? || member_and_cardholder?
  end

  def activate?
    (user&.admin? || member_and_cardholder?) && !record.canceled? && !record.event&.financially_frozen?
  end

  def show?
    user&.auditor? || OrganizerPosition.role_at_least?(user, record.event, :reader) || grantee?
  end

  def edit?
    admin_or_manager? || member_and_cardholder?
  end

  def update?
    admin_or_manager? || member_and_cardholder?
  end

  def transactions?
    user&.auditor? || OrganizerPosition.role_at_least?(user, record.event, :reader) || cardholder?
  end

  def ephemeral_keys?
    return false if record.card_grant&.pre_authorization&.unauthorized?

    cardholder?
  end

  def enable_cash_withdrawal?
    user&.admin?
  end

  # See ApplicationPolicy#visible_attributes. v3's `card` entity publishes the
  # name, type, status, issue date and the cardholder — not the PAN digits,
  # expiry, spend, or the shipping address.
  def visible_attributes
    @visible_attributes ||= begin
      attrs = []
      attrs += %i[type status name user user_id organization organization_id] if transparent_or_reader?

      if event_reader? || !!user&.auditor? || grantee?
        attrs += %i[last4 exp_month exp_year total_spent_cents balance_available
                    personalization last_frozen_by last_frozen_by_id]
      end

      attrs << :shipping if shipping?

      attrs
    end
  end

  private

  def member_and_cardholder?
    member? && cardholder?
  end

  def member?
    OrganizerPosition.role_at_least?(user, record.event, :member)
  end

  def cardholder?
    record.user == user
  end

  def admin_or_manager?
    user&.admin? || OrganizerPosition.role_at_least?(user, record.event, :manager)
  end

  def grantee?
    cardholder? && record.card_grant
  end

end
