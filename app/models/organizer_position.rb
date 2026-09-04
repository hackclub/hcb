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

  validates :user, uniqueness: { scope: :event, conditions: -> { where(deleted_at: nil) } }
  validate :user_must_be_verified, on: :create
  validate :fs_contract_is_proper_type, if: -> { fiscal_sponsorship_contract_changed? }

  delegate :initial?, to: :organizer_position_invite, allow_nil: true
  has_many :stripe_cards, ->(organizer_position) { where event_id: organizer_position.event.id }, through: :user

  alias_attribute :signee, :is_signee

  after_create_commit :autofollow_event

  # Keeps the per-request role_at_least? memo honest when a position is created,
  # changed, or removed inside the same request that later re-checks a role.
  after_save :clear_role_at_least_cache
  after_destroy :clear_role_at_least_cache

  def tourable_options
    {
      demo: event.demo_mode?,
      initial: initial?
    }
  end

  def self.role_at_least?(user, event, role)
    return false unless event.present? && role.present?
    return true if user&.admin?

    # The answer depends only on (user, event, role), but list views authorize
    # every row: a 100-row ledger page asked this ~300 times for one event,
    # each ask costing an `exists?` plus the recursive ancestor_ids CTE. Memoize
    # for the life of the request/job — CurrentAttributes resets between them,
    # and `clear_role_at_least_cache!` below drops the memo as soon as any
    # position changes, so a granted or revoked role is never served stale.
    #
    # Unsaved events have no stable identity to key on, so they skip the memo.
    return uncached_role_at_least?(user, event, role) if event.id.nil?

    cache = (Current.role_at_least_cache ||= {})
    cache.fetch([user&.id, event.id, role.to_s]) do |key|
      cache[key] = uncached_role_at_least?(user, event, role)
    end
  end

  def self.uncached_role_at_least?(user, event, role)
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

    false
  end
  private_class_method :uncached_role_at_least?

  # Any write to a position can change a role_at_least? answer, so drop the
  # whole memo rather than trying to predict which keys it invalidates (a
  # position on an ancestor event affects descendants too).
  def self.clear_role_at_least_cache!
    Current.role_at_least_cache = nil
  end

  private

  def clear_role_at_least_cache
    self.class.clear_role_at_least_cache!
  end

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

  private

  def user_must_be_verified
    if user&.unverified?
      errors.add(:user, "must verify their email before becoming an organizer")
    end
  end

end
