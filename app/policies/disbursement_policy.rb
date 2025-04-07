# frozen_string_literal: true

class DisbursementPolicy < ApplicationPolicy
  def show?
    user.auditor?
  end

  def new?
    user&.admin? || (
      (record.destination_event.nil? || record.destination_event.users.include?(user)) &&
      (record.source_event.nil?      || record.source_event.users.include?(user))
    )
  end

  def create?
    user&.admin? || (
      record.destination_event.users.include?(user) &&
      Pundit.policy(user, record.source_event).create_transfer?
    )
  end

  def transfer_confirmation_letter?
    auditor_or_user?
  end

  def edit?
    user.admin?
  end

  def update?
    user.admin?
  end

  def cancel?
    user.admin?
  end

  def mark_fulfilled?
    user.admin?
  end

  def reject?
    user.admin?
  end

  def pending_disbursements?
    user.admin?
  end

  private

  def auditor_or_user?
    user&.auditor? || record.event.users.include?(user)
  end

end
