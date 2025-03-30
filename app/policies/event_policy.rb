# frozen_string_literal: true

class EventPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  # Event homepage
  def show?
    is_public || OrganizerPosition.role_at_least?(user, record, :reader)
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
    admin?
  end

  def new?
    admin?
  end

  def create?
    admin?
  end

  def balance_by_date?
    is_public || member_or_higher?
  end

  def shipping?
    member_or_higher?
  end

  def edit?
    OrganizerPosition.role_at_least?(user, record, :manager)
  end

  def pin?
    member_or_higher?
  end

  def update?
    OrganizerPosition.role_at_least?(user, record, :manager)
  end

  alias remove_header_image? update?
  alias remove_background_image? update?
  alias remove_logo? update?
  alias enable_feature? update?
  alias disable_feature? update?

  def validate_slug?
    member_or_higher?
  end

  def destroy?
    admin? && record.demo_mode?
  end

  def team?
    is_public || auditor_or_user?
  end

  def emburse_card_overview?
    is_public || auditor_or_user?
  end

  def card_overview?
    (is_public || auditor_or_user?) && record.approved? && record.plan.cards_enabled?
  end

  def new_stripe_card?
    create_stripe_card?
  end

  def create_stripe_card?
    member_or_higher? && is_not_demo_mode?
  end

  def documentation?
    OrganizerPosition.role_at_least?(user, record, :reader) && record.plan.documentation_enabled?
  end

  def statements?
    is_public || member_or_higher?
  end

  def async_balance?
    is_public || member_or_higher?
  end

  def create_transfer?
    OrganizerPosition.role_at_least?(user, record, :manager) && !record.demo_mode?
  end

  def new_transfer?
    OrganizerPosition.role_at_least?(user, record, :manager) && !record.demo_mode?
  end

  def g_suite_overview?
    member_or_higher? && is_not_demo_mode? && record.plan.google_workspace_enabled?
  end

  def g_suite_create?
    OrganizerPosition.role_at_least?(user, record, :manager) && is_not_demo_mode? && record.plan.google_workspace_enabled?
  end

  def g_suite_verify?
    member_or_higher? && is_not_demo_mode? && record.plan.google_workspace_enabled?
  end

  def transfers?
    (is_public || member_or_higher?) && record.plan.transfers_enabled?
  end

  def promotions?
    member_or_higher? && record.plan.promotions_enabled?
  end

  def reimbursements_pending_review_icon?
    is_public || member_or_higher?
  end

  def reimbursements?
    OrganizerPosition.role_at_least?(user, record, :reader) && record.plan.reimbursements_enabled?
  end

  def employees?
    member_or_higher?
  end

  def donation_overview?
    (is_public || member_or_higher?) && record.approved? && record.plan.donations_enabled?
  end

  def account_number?
    OrganizerPosition.role_at_least?(user, record, :manager) && record.plan.account_number_enabled?
  end

  def toggle_event_tag?
    admin?
  end

  def receive_grant?
    OrganizerPosition.role_at_least?(user, record, :member)
  end

  def audit_log?
    admin?
  end

  def termination?
    admin?
  end

  def can_invite_user?
    OrganizerPosition.role_at_least?(user, record, :manager)
  end

  def claim_point_of_contact?
    admin?
  end

  def activation_flow?
    admin? && record.demo_mode?
  end

  def activate?
    admin? && record.demo_mode?
  end

  private

  def member_or_higher?
    auditor? || OrganizerPosition.role_at_least?(user, record, :member)
  end

  def auditor_or_user?
    auditor? || user?
  end

  def admin?
    user&.admin?
  end

  def auditor?
    user&.auditor?
  end

  def user?
    record.users.include?(user)
  end

  def manager?
    OrganizerPosition.find_by(user:, event: record)&.manager?
  end

  def is_not_demo_mode?
    !record.demo_mode?
  end

  def is_public
    record.is_public?
  end

end
