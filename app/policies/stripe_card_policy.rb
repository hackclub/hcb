# frozen_string_literal: true

class StripeCardPolicy < ApplicationPolicy
  def index?
    auditor?
  end

  def shipping?
    auditor? || OrganizerPosition.role_at_least?(user, record.event, :reader)
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
    (admin? || member_and_cardholder?) && !record.canceled? && !record.event&.financially_frozen?
  end

  def show?
    auditor? || OrganizerPosition.role_at_least?(user, record.event, :reader) || grantee?
  end

  def edit?
    admin_or_manager? || member_and_cardholder?
  end

  def update?
    admin_or_manager? || member_and_cardholder?
  end

  def transactions?
    auditor? || OrganizerPosition.role_at_least?(user, record.event, :reader) || cardholder?
  end

  def ephemeral_keys?
    return false if record.card_grant&.pre_authorization&.unauthorized?

    cardholder?
  end

  def enable_cash_withdrawal?
    admin?
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
    admin? || OrganizerPosition.role_at_least?(user, record.event, :manager)
  end

  def grantee?
    cardholder? && record.card_grant
  end

end
