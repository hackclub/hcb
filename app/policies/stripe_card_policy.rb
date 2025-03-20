# frozen_string_literal: true

class StripeCardPolicy < ApplicationPolicy
  def index?
    user&.auditor?
  end

  def shipping?
    user&.auditor? || organizer?
  end

  def freeze?
    admin_or_manager? || organizer_and_cardholder?
  end

  def defrost?
    freeze?
  end

  def cancel?
    admin_or_manager? || organizer_and_cardholder?
  end

  def activate?
    (user&.admin? || organizer_and_cardholder?) && !record&.canceled?
  end

  def show?
    user&.auditor? || organizer?
  end

  def edit?
    admin_or_manager? || organizer_and_cardholder?
  end

  def update?
    admin_or_manager? || organizer_and_cardholder?
  end

  def transactions?
    user&.auditor? || organizer? || cardholder?
  end

  def ephemeral_keys?
    cardholder? || user&.auditor?
  end

  def enable_cash_withdrawal?
    user&.admin?
  end

  private

  def organizer_and_cardholder?
    organizer? && cardholder?
  end

  def organizer?
    record&.event&.users&.include?(user)
  end

  def cardholder?
    record&.user == user
  end

  def admin_or_manager?
    user&.admin? || OrganizerPosition.find_by(user:, event: record.event)&.manager?
  end

end
