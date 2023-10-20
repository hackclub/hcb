# frozen_string_literal: true

# == Schema Information
#
# Table name: organizer_positions
#
#  id         :bigint           not null, primary key
#  deleted_at :datetime
#  first_time :boolean          default(TRUE)
#  is_signee  :boolean
#  role       :integer          default("member"), not null
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
  ROLES = [:member, :manager].freeze

  acts_as_paranoid
  has_paper_trail

  scope :not_hidden, -> { where(event: { hidden_at: nil }) }

  belongs_to :user
  belongs_to :event

  has_one :organizer_position_invite
  has_many :organizer_position_deletion_requests
  has_many :tours, as: :tourable

  enum :role, ROLES, default: :member

  def role_title
    if user.admin?
      "Admin"
    else
      role.humanize
    end
  end

  def role_color
    if user.admin?
      "warning"
    elsif manager?
      "info"
    else
      "muted"
    end

  end

  validates :user, uniqueness: { scope: :event, conditions: -> { where(deleted_at: nil) } }

  def initial?
    organizer_position_invite.initial?
  end

  def tourable_options
    {
      demo: event.demo_mode?,
      category: event.category,
      initial: initial?
    }
  end

  def signee?
    is_signee
  end

end
