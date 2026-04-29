# frozen_string_literal: true

class UserPolicy < ApplicationPolicy
  def show?
    auditor? || record == user
  end

  def impersonate?
    admin?
  end

  def edit?
    auditor? || record == user
  end

  def generate_totp?
    admin? || record == user
  end

  def enable_totp?
    admin? || record == user
  end

  def disable_totp?
    admin? || record == user
  end

  def generate_backup_codes?
    record == user
  end

  def activate_backup_codes?
    record == user
  end

  def disable_backup_codes?
    admin? || record == user
  end

  def edit_address?
    auditor? || record == user
  end

  def edit_payout?
    auditor? || record == user
  end

  def edit_featurepreviews?
    auditor? || record == user
  end

  def edit_security?
    auditor? || record == user
  end

  def edit_notifications?
    auditor? || record == user
  end

  def edit_integrations?
    auditor? || record == user
  end

  def edit_admin?
    auditor? || (record == user && user.admin_override_pretend?)
  end

  def admin_details?
    auditor?
  end

  def admin_details_stripe_transactions?
    auditor?
  end

  def update?
    admin? || record == user
  end

  def delete_profile_picture?
    admin? || record == user
  end

  def toggle_sms_auth?
    admin? || record == user
  end

  def start_sms_auth_verification?
    admin? || record == user
  end

  def complete_sms_auth_verification?
    admin? || record == user
  end

  def receipt_report?
    admin? || record == user
  end

  def enable_feature?
    admin? || record == user
  end

  def disable_feature?
    admin? || record == user
  end

  def logout_session?
    admin? || record == user
  end

  def logout_all?
    admin? || record == user
  end

  def toggle_pretend_is_not_admin?
    auditor? || (record == user && user.admin_override_pretend?)
  end

end
