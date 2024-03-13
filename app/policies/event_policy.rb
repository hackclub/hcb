# frozen_string_literal: true

class EventPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def toggle_hidden?
    user&.admin?
  end

  def new?
    user&.admin?
  end

  def create?
    user&.admin?
  end

  def show?
    is_public || admin_or_user?
  end

  # NOTE(@lachlanjc): this is bad, I’m sorry.
  # This is the StripeCardsController#shipping method when rendered on the event
  # card overview page. This should be moved out of here.
  def shipping?
    admin_or_user?
  end

  def by_airtable_id?
    user&.admin?
  end

  def edit?
    admin_or_manager?
  end

  def update?
    admin_or_manager?
  end

  def destroy?
    user&.admin? && record.demo_mode?
  end

  def team?
    is_public || admin_or_user?
  end

  def emburse_card_overview?
    is_public || admin_or_user?
  end

  def card_overview?
    is_public || admin_or_user?
  end

  def documentation?
    is_public || admin_or_user?
  end

  def statements?
    is_public || admin_or_user?
  end

  def demo_mode_request_meeting?
    admin_or_user?
  end

  # (@eilla1) these pages are for the wip resources page and should be moved later
  def connect_gofundme?
    is_public || admin_or_user?
  end

  def async_balance?
    is_public || admin_or_user?
  end

  def new_transfer?
    admin_or_manager?
  end

  def receive_check?
    is_public || admin_or_user?
  end

  def sell_merch?
    is_public || admin_or_user?
  end

  def g_suite_overview?
    admin_or_user? && !record.hardware_grant?
  end

  def g_suite_create?
    admin_or_user? && is_not_demo_mode? && !record.hardware_grant?
  end

  def g_suite_verify?
    admin_or_user?
  end

  def transfers?
    is_public || admin_or_user?
  end

  def promotions?
    (is_public || admin_or_user?) && !record.hardware_grant? && !record.outernet_guild?
  end

  def reimbursements?
    admin_or_user?
  end

  def donation_overview?
    is_public || admin_or_user?
  end

  def partner_donation_overview?
    is_public || admin_or_user?
  end

  def remove_header_image?
    admin_or_manager?
  end

  def remove_background_image?
    admin_or_manager?
  end

  def remove_logo?
    admin_or_manager?
  end

  def enable_feature?
    admin_or_manager?
  end

  def disable_feature?
    admin_or_manager?
  end

  def account_number?
    admin_or_manager?
  end

  def toggle_event_tag?
    user.admin?
  end

  def receive_grant?
    record.users.include?(user)
  end

  def audit_log?
    user.admin?
  end

  def validate_slug?
    admin_or_user?
  end

  def admin_or_user?
    record.users.include?(user)
  end

  private

  def admin_or_manager?
    user&.admin? || OrganizerPosition.find_by(user:, event: record)&.manager?
  end

  def is_not_demo_mode?
    !record.demo_mode?
  end

  def is_public
    record.is_public?
  end

end
