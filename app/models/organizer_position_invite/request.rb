# frozen_string_literal: true

# == Schema Information
#
# Table name: organizer_position_invite_requests
#
#  id                                :bigint           not null, primary key
#  aasm_state                        :string           not null
#  created_at                        :datetime         not null
#  updated_at                        :datetime         not null
#  organizer_position_invite_link_id :bigint           not null
#  requester_id                      :bigint           not null
#
# Indexes
#
#  idx_on_organizer_position_invite_link_id_241807b5ee       (organizer_position_invite_link_id)
#  index_organizer_position_invite_requests_on_requester_id  (requester_id)
#
# Foreign Keys
#
#  fk_rails_...  (organizer_position_invite_link_id => organizer_position_invite_links.id)
#  fk_rails_...  (requester_id => users.id)
#
class OrganizerPositionInvite
  class Request < ApplicationRecord
    belongs_to :link, class_name: "OrganizerPositionInvite::Link", foreign_key: "organizer_position_invite_link_id"
		belongs_to :requester, class_name: "User"

    aasm timestamps: true do
      state :pending, default: true
      state :approved
      state :denied

      event :approve do
        transitions from: :pending, to: :approved
      end

      event :deny do
        transitions from: :pending, to: :denied
      end
    end
  end
end
