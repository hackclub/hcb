# frozen_string_literal: true

# == Schema Information
#
# Table name: organizer_positions
#
#  id                             :bigint           not null, primary key
#  deleted_at                     :datetime
#  first_time                     :boolean          default(TRUE)
#  is_signee                      :boolean          default(FALSE)
#  role                           :integer          default(100), not null
#  sort_index                     :integer
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  event_id                       :bigint           not null
#  fiscal_sponsorship_contract_id :bigint
#  user_id                        :bigint           not null
#
# Indexes
#
#  index_organizer_positions_on_event_id                        (event_id)
#  index_organizer_positions_on_fiscal_sponsorship_contract_id  (fiscal_sponsorship_contract_id)
#  index_organizer_positions_on_user_id                         (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#  fk_rails_...  (fiscal_sponsorship_contract_id => contracts.id)
#  fk_rails_...  (user_id => users.id)
#
class OrganizerPosition < ApplicationRecord
  acts_as_paranoid
  has_paper_trail
  include OrganizerPosition::HasRole
  include OrganizerPosition::HasSpending

  include Hashid::Rails

  include PublicIdentifiable
  set_public_id_prefix :opn

  scope :not_hidden, -> { where(event: { hidden_at: nil }) }

  belongs_to :user
  belongs_to :event
  belongs_to :fiscal_sponsorship_contract, optional: true, class_name: "Contract"

  has_one :organizer_position_invite, required: true
  has_many :organizer_position_deletion_requests
  has_many :tours, as: :tourable, dependent: :destroy
  has_many :reimbursement_reviewer_opt_ins, class_name: "Event::ReimbursementReviewer::OptIn", dependent: :destroy

  validates :user, uniqueness: { scope: :event, conditions: -> { where(deleted_at: nil) } }
  validate :user_must_be_verified, on: :create
  validate :fs_contract_is_proper_type, if: -> { fiscal_sponsorship_contract_changed? }
  validate :at_least_one_manager, on: :update
  validate :owner_has_signed_contract

  delegate :initial?, to: :organizer_position_invite, allow_nil: true
  has_many :stripe_cards, ->(organizer_position) { where event_id: organizer_position.event.id }, through: :user

  after_create_commit :autofollow_event

  after_update :remove_payroll_managers, if: :lost_manager_access?
  after_destroy :remove_payroll_managers
  after_create :opt_in_to_reimbursement_reviews, if: :manager_access?
  after_update :opt_in_to_reimbursement_reviews, if: :gained_manager_access?
  after_update :opt_out_of_reimbursement_reviews, if: :lost_manager_access?

  before_save -> { stripe_cards.active.find_each(&:freeze!) }, if: -> { will_save_change_to_role?(to: :reader) }

  def tourable_options
    {
      demo: event.demo_mode?,
      initial: initial?
    }
  end

  def self.role_at_least?(user, event, role)
    return false unless event.present? && role.present?
    return true if user&.admin?

    if role.to_s == "reader"
      return event.ancestor_organizer_positions.reader_access.where(user:).exists?
    end

    if role.to_s == "member"
      # Only check direct organizer positions, unless the user is a manager of an ancestor
      return event.organizer_positions.member_access.where(user:).exists? || event.ancestor_organizer_positions.manager_access.where(user:).exists?
    end

    if role.to_s == "manager"
      return event.ancestor_organizer_positions.manager_access.where(user:).exists?
    end

    if role.to_s == "owner"
      # Ownership comes from signing this organization's fiscal sponsorship
      # contract, so it is never inherited from an ancestor
      return event.organizer_positions.owner_access.where(user:).exists?
    end

    false
  end

  private

  def fs_contract_is_proper_type
    if fiscal_sponsorship_contract.present? && !fiscal_sponsorship_contract.is_a?(::Contract::FiscalSponsorship)
      errors.add(:fiscal_sponsorship_contract, "must be of type Contract::FiscalSponsorship")
    end
  end

  def autofollow_event
    if event.announcements.any? && !event.followers.include?(user:)
      event.event_follows.create!(user:)
    end

  rescue ActiveRecord::RecordNotUnique
    # Do nothing. The user already follows this event.
  end

  def user_must_be_verified
    if user&.unverified?
      errors.add(:user, "must verify their email before becoming an organizer")
    end
  end

  # Prevent the last manager (or owner) from being demoted, which would leave
  # the organization without anyone who can manage it
  def at_least_one_manager
    return unless will_save_change_to_role?

    previous_role = role_in_database
    return if previous_role.nil? || self.class.roles[previous_role] < self.class.roles[:manager]
    return if manager_access?
    return if event.organizer_positions.where.not(id:).manager_access.exists?

    errors.add(:event, "must have at least one manager")
  end

  def owner_has_signed_contract
    if owner? && !fiscal_sponsorship_contract&.signed?
      errors.add(:base, "owners must have an associated signed contract")
    end
  end

  def gained_manager_access?
    from, to = role_previous_change
    return false if from.nil? || to.nil?

    self.class.roles[from] < self.class.roles[:manager] && self.class.roles[to] >= self.class.roles[:manager]
  end

  def lost_manager_access?
    from, to = role_previous_change
    return false if from.nil? || to.nil?

    self.class.roles[from] >= self.class.roles[:manager] && self.class.roles[to] < self.class.roles[:manager]
  end

  # Managers review their own organization's reimbursement reports unless
  # they opt out in its settings
  def opt_in_to_reimbursement_reviews
    reimbursement_reviewer_opt_ins.find_or_create_by!(event:)
  end

  def opt_out_of_reimbursement_reviews
    reimbursement_reviewer_opt_ins.destroy_all
  end

  def remove_payroll_managers
    user.managing_payroll_positions.joins(:payee).where(payee: { event: }).find_each do |position|
      position.update!(manager: nil)
    end
  end

end
