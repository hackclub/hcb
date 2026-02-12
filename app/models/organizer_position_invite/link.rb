# frozen_string_literal: true

# == Schema Information
#
# Table name: organizer_position_invite_links
#
#  id             :bigint           not null, primary key
#  deactivated_at :datetime
#  expires_in     :integer          default(2592000), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  creator_id     :bigint           not null
#  deactivator_id :bigint
#  event_id       :bigint           not null
#
# Indexes
#
#  index_organizer_position_invite_links_on_creator_id      (creator_id)
#  index_organizer_position_invite_links_on_deactivator_id  (deactivator_id)
#  index_organizer_position_invite_links_on_event_id        (event_id)
#
# Foreign Keys
#
#  fk_rails_...  (creator_id => users.id)
#  fk_rails_...  (deactivator_id => users.id)
#  fk_rails_...  (event_id => events.id)
#
class OrganizerPositionInvite
  class Link < ApplicationRecord
    include Hashid::Rails
    hashid_config salt: ""

    DEFAULT_EXPIRATION = 30.days

    belongs_to :event
    belongs_to :creator, class_name: "User"
    belongs_to :deactivator, class_name: "User", optional: true

    has_many :requests, class_name: "OrganizerPositionInvite::Request", foreign_key: "organizer_position_invite_link_id", inverse_of: :link, dependent: :destroy

    scope :active, -> { where(deactivated_at: nil).where("? <= created_at + expires_in * interval '1 sec'", Time.now) }

    def active?
      !deactivated? && !expired?
    end

    def expired?
      Time.now.after?(created_at + expires_in.seconds)
    end

    def deactivated?
      deactivated_at.present?
    end

    def deactivate(user:)
      return false if deactivated?

      update(deactivated_at: Time.now, deactivator: user)
    end

  end

end
