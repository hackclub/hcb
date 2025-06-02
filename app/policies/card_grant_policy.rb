# frozen_string_literal: true

class CardGrantPolicy < ApplicationPolicy
  def new?
    admin_or_user?
  end

  def create?
    admin_or_manager? && record.event.plan.card_grants_enabled?
  end

  def show?
    user&.auditor? || record.user == user || user_in_event?
  end

  def spending?
    record.event.is_public? || user&.auditor? || user_in_event?
  end

  def activate?
    user&.admin? || record.user == user
  end

  def cancel?
    admin_or_user? || record.user == user
  end

  def topup?
    admin_or_manager? && record.active?
  end

  def withdraw?
    admin_or_manager? && record.active?
  end

  def update?
    admin_or_manager?
  end

  def convert_to_reimbursement_report?
    (admin_or_manager? || record.user == user) && record.card_grant_setting.reimbursement_conversions_enabled?
  end

  def toggle_one_time_use?
    admin_or_manager? && record.active?
  end

  def admin_or_user?
    user&.admin? || record.event.users.include?(user)
  end

  def admin_or_manager?
    user&.admin? || OrganizerPosition.find_by(user:, event: record.event)&.manager?
  end

  private

  def user_in_event?
    record.event.users.include?(user)
  end

end
