# frozen_string_literal: true

class EventPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  # Event homepage
  def show?
    is_public || allowed_user?
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
    is_public || allowed_user?
  end

  def shipping?
    allowed_user?
  end

  def edit?
    OrganizerPosition.role_at_least?(user, :manager)
  end

  def pin?
    allowed_user?
  end

  def update?
    OrganizerPosition.role_at_least?(user, :manager)
  end

  alias remove_header_image? update?
  alias remove_background_image? update?
  alias remove_logo? update?
  alias enable_feature? update?
  alias disable_feature? update?

  def validate_slug?
    allowed_user?
  end

  def destroy?
    admin? && record.demo_mode?
  end

  def team?
    is_public || allowed_user?
  end

  def emburse_card_overview?
    is_public || allowed_user?
  end

  def card_overview?
    (is_public || allowed_user?) && record.approved? && record.plan.cards_enabled?
  end

  def new_stripe_card?
    create_stripe_card?
  end

  def create_stripe_card?
    allowed_user? && is_not_demo_mode?
  end

  def documentation?
    allowed_user? && record.plan.documentation_enabled?
  end

  def statements?
    is_public || allowed_user?
  end

  def async_balance?
    is_public || allowed_user?
  end

  def create_transfer?
    OrganizerPosition.role_at_least?(user, :manager) && !record.demo_mode?
  end

  def new_transfer?
    OrganizerPosition.role_at_least?(user, :manager) && !record.demo_mode?
  end

  def g_suite_overview?
    allowed_user? && is_not_demo_mode? && record.plan.google_workspace_enabled?
  end

  def g_suite_create?
    OrganizerPosition.role_at_least?(user, :manager) && is_not_demo_mode? && record.plan.google_workspace_enabled?
  end

  def g_suite_verify?
    allowed_user? && is_not_demo_mode? && record.plan.google_workspace_enabled?
  end

  def transfers?
    (is_public || allowed_user?) && record.plan.transfers_enabled?
  end

  def promotions?
    allowed_user? && record.plan.promotions_enabled?
  end

  def reimbursements_pending_review_icon?
    is_public || allowed_user?
  end

  def reimbursements?
    OrganizerPosition.role_at_least?(user, :reader) && record.plan.reimbursements_enabled?
  end

  def employees?
    allowed_user?
  end

  def donation_overview?
    (is_public || allowed_user?) && record.approved? && record.plan.donations_enabled?
  end

  def account_number?
    OrganizerPosition.role_at_least?(user, :manager) && record.plan.account_number_enabled?
  end

  def toggle_event_tag?
    admin?
  end

  def receive_grant?
    OrganizerPosition.role_at_least?(user, :member)
  end

  def audit_log?
    admin?
  end

  def termination?
    admin?
  end

  def can_invite_user?
    OrganizerPosition.role_at_least?(user, :manager)
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

  def allowed_user?
    OrganizerPosition.role_at_least?(user, :member)
  end

  def admin?
    user&.admin?
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
