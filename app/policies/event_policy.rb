# frozen_string_literal: true

class EventPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def index_in_v4?
    auditor_or_reader?
  end

  # Event homepage
  def show?
    is_public || auditor_or_reader?
  end

  def show_in_v4?
    auditor_or_reader?
  end

  # Turbo frames for the event homepage (show)
  alias_method :team_stats?, :show?
  alias_method :recent_activity?, :show?
  alias_method :money_movement?, :show?
  alias_method :balance_transactions?, :show?
  alias_method :merchants_chart?, :show?
  alias_method :categories_chart?, :show?
  alias_method :top_categories?, :show?
  alias_method :tags_chart?, :show?
  alias_method :users_chart?, :show?
  alias_method :transaction_heatmap?, :show?

  alias_method :transactions?, :show?
  alias_method :ledger?, :transactions?
  alias_method :merchants_filter?, :transactions?

  def toggle_hidden?
    user&.admin?
  end

  def new?
    user&.admin?
  end

  def create?
    user&.admin?
  end

  def balance_by_date?
    is_public || auditor_or_reader?
  end

  def edit?
    auditor_or_member?
  end

  # pinning a transaction to an event
  def pin?
    admin_or_member?
  end

  def update?
    admin_or_manager?
  end

  alias remove_header_image? update?

  alias remove_background_image? update?

  alias remove_logo? update?

  alias enable_feature? update?

  alias disable_feature? update?

  alias toggle_fee_waiver_eligible? update?

  def validate_slug?
    admin_or_member?
  end

  def destroy?
    user&.admin? && record.demo_mode?
  end

  def team?
    is_public || auditor_or_reader?
  end

  def announcement_overview?
    is_public || record.announcements.published.any? || auditor_or_reader?
  end

  def feed?
    announcement_overview?
  end

  def emburse_card_overview?
    is_public || auditor_or_reader?
  end

  def card_overview?
    show? && record.approved? && record.plan.cards_enabled?
  end

  def card_overview_in_v4?
    show_in_v4? && card_overview?
  end

  def new_stripe_card?
    create_stripe_card?
  end

  def create_stripe_card?
    admin_or_member? && is_not_demo_mode?
  end

  def documentation?
    auditor_or_reader? && record.plan.documentation_enabled?
  end

  def statements?
    show?
  end

  def statement_of_activity?
    show? && auditor?
  end

  def async_balance?
    show?
  end

  def async_sub_organization_balance?
    sub_organizations?
  end

  def create_transfer?
    admin_or_manager? && !record.demo_mode?
  end

  def new_transfer?
    admin_or_manager? && !record.demo_mode?
  end

  def g_suite_overview?
    auditor_or_reader? && is_not_demo_mode? && record.plan.google_workspace_enabled?
  end

  def g_suite_create?
    admin_or_manager? && is_not_demo_mode? && record.plan.google_workspace_enabled?
  end

  def g_suite_verify?
    auditor_or_reader? && is_not_demo_mode? && record.plan.google_workspace_enabled?
  end

  def transfers?
    show? && record.plan.transfers_enabled?
  end

  def transfers_in_v4?
    show_in_v4? && transfers?
  end

  def card_grant_overview?
    (is_public || auditor_or_reader?) && (record.plan.card_grants_enabled? || record.card_grants.any?)
  end

  def bulk_upload_card_grants?
    admin_or_manager? && record.plan.card_grants_enabled?
  end

  def promotions?
    auditor_or_reader?
  end

  def reimbursements_pending_review_icon?
    show?
  end

  def reimbursements?
    auditor_or_reader? && record.plan.reimbursements_enabled?
  end

  def employees?
    auditor_or_reader? && Flipper.enabled?(:payroll_2025_02_13, record)
  end

  def sub_organizations?
    (is_public || auditor_or_reader?) && (record.subevents_enabled? || record.subevents.any?)
  end

  def sub_organizations_in_v4?
    auditor_or_reader? && sub_organizations?
  end

  def create_sub_organization?
    admin_or_manager? && record.subevents_enabled?
  end

  def donation_overview?
    show? && record.approved? && record.plan.donations_enabled? && record.donation_page_enabled?
  end

  def invoices?
    show? && record.approved? && record.plan.invoices_enabled?
  end

  def account_number?
    (auditor? || member?) && record.plan.account_number_enabled?
  end

  def toggle_event_tag?
    user.admin?
  end

  def receive_grant?
    record.users.include?(user)
  end

  def audit_log?
    user.auditor?
  end

  def termination?
    user&.auditor?
  end

  def can_invite_user?
    admin_or_manager?
  end

  def claim_point_of_contact?
    user&.admin?
  end

  def activation_flow?
    user&.admin? && record.demo_mode?
  end

  def activate?
    user&.admin? && record.demo_mode?
  end

  def toggle_scoped_tag?
    admin_or_manager?
  end

  private

  def admin_or_member?
    admin? || member?
  end

  def auditor_or_reader?
    auditor? || reader?
  end

  def auditor_or_member?
    auditor? || member?
  end

  def admin?
    user&.admin?
  end

  def auditor?
    user&.auditor?
  end

  def reader?
    OrganizerPosition.role_at_least?(user, record, :reader)
  end

  def member?
    OrganizerPosition.role_at_least?(user, record, :member)
  end

  def manager?
    OrganizerPosition.role_at_least?(user, record, :manager)
  end

  def admin_or_manager?
    admin? || manager?
  end

  def admin_or_reader?
    admin? || reader?
  end

  def is_not_demo_mode?
    !record.demo_mode?
  end

  def is_public
    record.is_public?
  end

end
