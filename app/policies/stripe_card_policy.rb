# frozen_string_literal: true

class StripeCardPolicy < ApplicationPolicy
  def index?
    user&.auditor?
  end

  def shipping?
    user&.auditor? || OrganizerPosition.role_at_least?(user, record&.event, :reader)
  end

  def freeze?
    admin_or_manager? || member_and_cardholder? || grantee?
  end

  def defrost?
    if grantee? && !member? && (record.last_frozen_by != current_user)
      return false
    end

    freeze? && !record.event.financially_frozen?
  end

  def cancel?
    admin_or_manager? || member_and_cardholder?
  end

  def activate?
    (user&.admin? || member_and_cardholder?) && !record&.canceled? && !record.event.financially_frozen?
  end

  def show?
    user&.auditor? || OrganizerPosition.role_at_least?(user, record&.event, :reader) || grantee?
  end

  def edit?
    admin_or_manager? || member_and_cardholder?
  end

  def update?
    admin_or_manager? || member_and_cardholder?
  end

  def transactions?
    user&.auditor? || OrganizerPosition.role_at_least?(user, record&.event, :reader) || cardholder?
  end

  def ephemeral_keys?
    cardholder? || user&.auditor?
  end

  def enable_cash_withdrawal?
    user&.admin?
  end

  private

  def member_and_cardholder?
    member? && cardholder?
  end

  def member?
    OrganizerPosition.role_at_least?(user, record&.event, :member)
  end

  def cardholder?
    record&.user == user
  end

  def admin_or_manager?
    user&.admin? || OrganizerPosition.find_by(user:, event: record.event)&.manager?
  end

  def grantee?
    cardholder? && record.card_grant
  end

end
