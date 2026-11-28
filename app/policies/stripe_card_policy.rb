# frozen_string_literal: true

class StripeCardPolicy < ApplicationPolicy
  def index?
    user&.auditor?
  end

  def shipping?
    user&.auditor? || OrganizerPosition.role_at_least?(user, record.event, :reader)
  end

  def freeze?
    admin_or_manager? || member_and_cardholder? || locked_out_cardholder? || grantee?
  end

  def defrost?
    return false if record.event&.financially_frozen?
    return false if record.user.locked?
    return false if record.last_frozen_by.present? && record.last_frozen_by != user && !admin_or_manager?

    freeze?
  end

  def cancel?
    admin_or_manager? || member_and_cardholder? || locked_out_cardholder?
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
    return false if record.event&.two_factor_authentication_overdue_for?(user)

    cardholder?
  end

  def enable_cash_withdrawal?
    user&.admin?
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

  # Losing access to the organization for not enabling two-factor
  # authentication shouldn't stop a cardholder from freezing or cancelling
  # their own lost card.
  def locked_out_cardholder?
    cardholder? && record.event.present? && record.event.two_factor_authentication_overdue_for?(user) && record.event.organizer_positions.exists?(user:)
  end

  def admin_or_manager?
    user&.admin? || OrganizerPosition.role_at_least?(user, record.event, :manager)
  end

  def grantee?
    cardholder? && record.card_grant
  end

end
