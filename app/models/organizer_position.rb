# frozen_string_literal: true

# == Schema Information
#
# Table name: organizer_positions
#
#  id         :bigint           not null, primary key
#  deleted_at :datetime
#  first_time :boolean          default(TRUE)
#  is_signee  :boolean          default(FALSE)
#  role       :integer          default("manager"), not null
#  sort_index :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  event_id   :bigint
#  user_id    :bigint
#
# Indexes
#
#  index_organizer_positions_on_event_id  (event_id)
#  index_organizer_positions_on_user_id   (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#  fk_rails_...  (user_id => users.id)
#
class OrganizerPosition < ApplicationRecord
  acts_as_paranoid
  has_paper_trail
  include OrganizerPosition::HasRole
  include OrganizerPosition::HasSpending

  scope :not_hidden, -> { where(event: { hidden_at: nil }) }

  belongs_to :user
  belongs_to :event

  has_one :organizer_position_invite, required: true
  has_many :organizer_position_deletion_requests
  has_many :tours, as: :tourable, dependent: :destroy

  validates :user, uniqueness: { scope: :event, conditions: -> { where(deleted_at: nil) } }

  delegate :initial?, to: :organizer_position_invite, allow_nil: true
  has_many :stripe_cards, ->(organizer_position) { where event_id: organizer_position.event.id }, through: :user

  alias_attribute :signee, :is_signee

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

    false
  end

  private

end
