# frozen_string_literal: true

class UserPolicy < ApplicationPolicy
  def show?
    user.auditor? || record == user
  end

  # See ApplicationPolicy#visible_attributes.
  #
  # `name` is in every tier — it is the one field on this record whose *value*
  # changes rather than its presence, which is why `full_name?` exists
  # alongside the list. See the comment on that method.
  def visible_attributes
    @visible_attributes ||= begin
      attrs = %i[name avatar admin auditor]
      attrs << :email if own_record? || shares_org_with_viewer?
      attrs += %i[birthday shipping_address billing_address] if own_record?
      attrs
    end
  end

  # A list of visible fields can only say whether a field is present. It cannot
  # express a field that is always present but carries a different value per
  # viewer, and `name` is exactly that: outside the viewer's organizations it
  # degrades to `User#initial_name` ("Mohamad A.") rather than disappearing.
  # Dropping the key instead would break v3 clients, which always receive a
  # name. Serializers and views pick the value; the policy makes the decision.
  def full_name?
    own_record? || shares_org_with_viewer? || user&.auditor?
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

  def pay?
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

  def admin_details_emburse_cards?
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

  def admin_details_stripe_cards?
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

  def reset_billing_address?
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

  def suppress_card_locking?
    user.admin?
  end

  private

  def own_record?
    user.present? && record == user
  end

  # Mirrors `Api::V4::ApplicationHelper#shares_org_with?`, moved onto the policy
  # so the web UI and the API resolve it the same way.
  #
  # We check organizer positions rather than read access on purpose: your email
  # is not visible to someone merely because they can read an organization you
  # belong to. Organizers of a child organization do not see the email
  # addresses of organizers in the parent.
  def shares_org_with_viewer?
    return false if user.nil? || record.nil?

    viewer_event_ids = user.readable_event_ids
    return false if viewer_event_ids.empty?

    # `map` rather than `pluck` so a preloaded association is actually used —
    # this runs once per rendered user, and index routes must preload it.
    viewer_event_ids.intersect?(record.organizer_positions.map(&:event_id).to_set)
  end

end
