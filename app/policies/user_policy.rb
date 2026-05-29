# frozen_string_literal: true

class UserPolicy < ApplicationPolicy
  def show?
    user.auditor? || record == user
  end

  def impersonate?
    user.admin?
  end

  def edit?
    user.auditor? || record == user
  end

  def generate_totp?
    user.admin? || record == user
  end

  def enable_totp?
    user.admin? || record == user
  end

  def disable_totp?
    user.admin? || record == user
  end

  def generate_backup_codes?
    record == user
  end

  def activate_backup_codes?
    record == user
  end

  def disable_backup_codes?
    user.admin? || record == user
  end

  def edit_address?
    user.auditor? || record == user
  end

  def edit_payout?
    user.auditor? || record == user
  end

  def edit_featurepreviews?
    user.auditor? || record == user
  end

  def edit_security?
    user.auditor? || record == user
  end

  def edit_notifications?
    user.auditor? || record == user
  end

  def edit_integrations?
    user.auditor? || record == user
  end

  def edit_admin?
    user.auditor? || (record == user && user.admin_override_pretend?)
  end

  def admin_details?
    user.auditor?
  end

  def admin_details_ach_transfers?
    admin_details?
  end

  def admin_details_check_deposits?
    admin_details?
  end

  def admin_details_disbursements?
    admin_details?
  end

  def admin_details_increase_checks?
    admin_details?
  end

  def admin_details_invoices?
    admin_details?
  end

  def admin_details_lob_checks?
    admin_details?
  end

  def admin_details_missing_receipts?
    admin_details?
  end

  def admin_details_reimbursement_reports?
    admin_details?
  end

  def admin_details_stripe_transactions?
    admin_details?
  end

  def update?
    user.admin? || record == user
  end

  def delete_profile_picture?
    user.admin? || record == user
  end

  def toggle_sms_auth?
    user.admin? || record == user
  end

  def start_sms_auth_verification?
    user.admin? || record == user
  end

  def complete_sms_auth_verification?
    user.admin? || record == user
  end

  def receipt_report?
    user.admin? || record == user
  end

  def enable_feature?
    user.admin? || record == user
  end

  def disable_feature?
    user.admin? || record == user
  end

  def logout_session?
    user.admin? || record == user
  end

  def logout_all?
    user.admin? || record == user
  end

  def toggle_pretend_is_not_admin?
    user.auditor? || (record == user && user.admin_override_pretend?)
  end

end
