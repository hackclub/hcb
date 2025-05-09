# frozen_string_literal: true

class EventPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  # Event homepage
  def show?
    is_public || auditor_or_reader?
  end

  # Turbo frames for the event homepage (show)
  alias_method :team_stats?, :show?
  alias_method :recent_activity?, :show?
  alias_method :money_movement?, :show?
  alias_method :balance_transactions?, :show?
  alias_method :merchants_categories?, :show?
  alias_method :top_categories?, :show?
  alias_method :tags_users?, :show?
  alias_method :transaction_heatmap?, :show?

  alias_method :transactions?, :show?
  alias_method :ledger?, :transactions?

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

  # NOTE(@lachlanjc): this is bad, I’m sorry.
  # This is the StripeCardsController#shipping method when rendered on the event
  # card overview page. This should be moved out of here.
  def shipping?
    auditor_or_reader?
  end

  def edit?
    admin_or_reader?
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

  def validate_slug?
    admin_or_member?
  end

  def destroy?
    user&.admin? && record.demo_mode?
  end

  def team?
    is_public || auditor_or_reader?
  end

  def emburse_card_overview?
    is_public || auditor_or_reader?
  end

  def card_overview?
    (is_public || auditor_or_reader?) && record.approved? && record.plan.cards_enabled?
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
    is_public || auditor_or_reader?
  end

  def async_balance?
    is_public || auditor_or_reader?
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
    (is_public || auditor_or_reader?) && record.plan.transfers_enabled?
  end

  def promotions?
    auditor_or_reader? && record.plan.promotions_enabled?
  end

  def reimbursements_pending_review_icon?
    is_public || auditor_or_reader?
  end

  def reimbursements?
    auditor_or_reader? && record.plan.reimbursements_enabled?
  end

  def employees?
    auditor_or_reader?
  end

  def donation_overview?
    (is_public || auditor_or_reader?) && record.approved? && record.plan.donations_enabled?
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

  private

  def admin_or_member?
    admin? || member?
  end

  def auditor_or_reader?
    auditor? || reader?
  end

  def admin?
    user&.admin?
  end

  def auditor?
    user&.auditor?
  end

  def member?
    OrganizerPosition.role_at_least?(user, record, :member)
  end

  def reader?
    OrganizerPosition.role_at_least?(user, record, :reader)
  end

  def manager?
    OrganizerPosition.find_by(user:, event: record)&.manager?
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
