# frozen_string_literal: true

class CardGrantPolicy < ApplicationPolicy
  def new?
    admin_or_user?
  end

  def create?
    admin_or_manager? && sender_admin_or_manager? && record.event.plan.card_grants_enabled?
  end

  def show?
    user&.auditor? || cardholder? || user_in_event?
  end

  def transactions?
    user&.auditor? || cardholder? || user_in_event?
  end

  def spending?
    record.event.is_public? || user&.auditor? || user_in_event?
  end

  def edit_actions?
    admin_or_manager?
  end

  def edit_usage_restrictions?
    admin_or_manager?
  end

  def edit_overview?
    admin_or_manager?
  end

  def edit_balance?
    admin_or_manager?
  end

  def edit_purpose?
    admin_or_manager?
  end

  def edit_topup?
    admin_or_manager?
  end

  def edit_withdraw?
    admin_or_manager?
  end

  def activate?
    (user&.admin? || (cardholder? && authorized_to_activate?)) && record.active?
  end

  def cancel?
    (admin_or_manager? || cardholder?) && record.active?
  end

  def convert_to_reimbursement_report?
    (admin_or_manager? || cardholder?) && record.active? && record.card_grant_setting.reimbursement_conversions_enabled?
  end

  def edit?
    admin_or_manager? && record.active?
  end

  def toggle_one_time_use?
    admin_or_manager? && record.active?
  end

  def disable_pre_authorization?
    admin_or_manager? && record.pre_authorization_required?
  end

  def topup?
    admin_or_manager? && record.active?
  end

  def withdraw?
    admin_or_manager? && record.active?
  end

  def permit_merchant?
    admin_or_manager? && record.active?
  end

  def update?
    admin_or_manager? && record.active?
  end

  private

  def admin_or_user?
    user&.admin? || record.event.users.include?(user)
  end

  def admin_or_manager?
    user&.admin? || OrganizerPosition.find_by(user:, event: record.event)&.manager?
  end

  def sender_admin_or_manager?
    return true if record.sent_by.nil? # May be nil if used to authorize after build on #new page.

    record.sent_by.admin? || OrganizerPosition.find_by(user: record.sent_by, event: record.event)&.manager?
  end

  def user_in_event?
    OrganizerPosition.role_at_least?(user, record, :reader)
  end

  def authorized_to_activate?
    record.pre_authorization.nil? || record.pre_authorization.approved? || record.pre_authorization.fraudulent?
  end

  def cardholder?
    record.user == user
  end

end
