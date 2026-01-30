# frozen_string_literal: true

# == Schema Information
#
# Table name: organizer_position_invite_requests
#
#  id                                :bigint           not null, primary key
#  aasm_state                        :string           not null
#  created_at                        :datetime         not null
#  updated_at                        :datetime         not null
#  organizer_position_invite_id      :bigint
#  organizer_position_invite_link_id :bigint           not null
#  requester_id                      :bigint           not null
#
# Indexes
#
#  idx_on_organizer_position_invite_id_0bf62e304a            (organizer_position_invite_id)
#  idx_on_organizer_position_invite_link_id_241807b5ee       (organizer_position_invite_link_id)
#  index_organizer_position_invite_requests_on_requester_id  (requester_id)
#
# Foreign Keys
#
#  fk_rails_...  (organizer_position_invite_id => organizer_position_invites.id)
#  fk_rails_...  (organizer_position_invite_link_id => organizer_position_invite_links.id)
#  fk_rails_...  (requester_id => users.id)
#
class OrganizerPositionInvite
  class Request < ApplicationRecord
    include Hashid::Rails
    include AASM

    belongs_to :organizer_position_invite, optional: true
    belongs_to :link, class_name: "OrganizerPositionInvite::Link", foreign_key: "organizer_position_invite_link_id", inverse_of: :requests
    belongs_to :requester, class_name: "User"

    after_create_commit do
      OrganizerPositionInvite::RequestsMailer.with(request: self).created.deliver_later
    end

    aasm timestamps: true do
      state :pending, default: true
      state :approved
      state :denied

      event :approve do
        transitions from: :pending, to: :approved
      end

      event :deny do
        transitions from: :pending, to: :denied
        after do
          OrganizerPositionInvite::RequestsMailer.with(request: self).denied.deliver_later
        end
      end
    end

  end

end
