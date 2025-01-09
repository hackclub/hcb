# frozen_string_literal: true

class EventPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  # Event homepage
  def show?
    is_public || admin_or_user?
  end

  # Turbo frames for the event homepage (show)
  alias_method :merchants_categories?, :show?
  alias_method :top_categories?, :show?
  alias_method :tags_users?, :show?
  alias_method :transaction_heatmap?, :show?

  alias_method :transactions?, :show?

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
    is_public || admin_or_user?
  end

  # NOTE(@lachlanjc): this is bad, I’m sorry.
  # This is the StripeCardsController#shipping method when rendered on the event
  # card overview page. This should be moved out of here.
  def shipping?
    admin_or_user?
  end

  def edit?
    admin_or_user?
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
    admin_or_user?
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
    (is_public || admin_or_user?) && record.approved? && record.plan.cards_enabled?
  end

  def new_stripe_card?
    create_stripe_card?
  end

  def create_stripe_card?
    admin_or_user? && is_not_demo_mode?
  end

  def documentation?
    admin_or_user? && record.plan.documentation_enabled?
  end

  def statements?
    is_public || admin_or_user?
  end

  def async_balance?
    is_public || admin_or_user?
  end

  def create_transfer?
    admin_or_manager? && !record.demo_mode?
  end

  def new_transfer?
    admin_or_manager? && !record.demo_mode?
  end

  def g_suite_overview?
    admin_or_user? && is_not_demo_mode? && record.plan.google_workspace_enabled?
  end

  def g_suite_create?
    admin_or_manager? && is_not_demo_mode? && record.plan.google_workspace_enabled?
  end

  def g_suite_verify?
    admin_or_user? && is_not_demo_mode? && record.plan.google_workspace_enabled?
  end

  def transfers?
    (is_public || admin_or_user?) && record.plan.transfers_enabled?
  end

  def promotions?
    admin_or_user? && record.plan.promotions_enabled?
  end

  def reimbursements_pending_review_icon?
    is_public || admin_or_user?
  end

  def reimbursements?
    admin_or_user? && record.plan.reimbursements_enabled?
  end

  def donation_overview?
    (is_public || admin_or_user?) && record.approved? && record.plan.donations_enabled?
  end

  def account_number?
    admin_or_manager? && record.plan.account_number_enabled?
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

  def termination?
    user&.admin?
  end

  def finish_signee_backfill?
    user&.admin?
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

  def admin_or_user?
    admin? || user?
  end

  def admin?
    user&.admin?
  end

  def user?
    record.users.include?(user)
  end

  def manager?
    OrganizerPosition.find_by(user:, event: record)&.manager?
  end

  def admin_or_manager?
    admin? || manager?
  end

  def is_not_demo_mode?
    !record.demo_mode?
  end

  def is_public
    record.is_public?
  end

end
