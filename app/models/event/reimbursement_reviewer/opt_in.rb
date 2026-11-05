# frozen_string_literal: true

# == Schema Information
#
# Table name: event_reimbursement_reviewer_opt_ins
#
#  id                    :bigint           not null, primary key
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  event_id              :bigint           not null
#  organizer_position_id :bigint           not null
#
# Indexes
#
#  idx_on_organizer_position_id_event_id_8a61c152af        (organizer_position_id,event_id) UNIQUE
#  index_event_reimbursement_reviewer_opt_ins_on_event_id  (event_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#  fk_rails_...  (organizer_position_id => organizer_positions.id)
#
class Event
  module ReimbursementReviewer
    # A manager who reviews `event`'s reimbursement reports that have no
    # assigned reviewer. Managers are opted in to their own organization when
    # they become a manager (see OrganizerPosition); managers of a parent
    # organization opt in to each sub-organization themselves.
    class OptIn < ApplicationRecord
      has_paper_trail

      belongs_to :organizer_position
      belongs_to :event
      has_one :user, through: :organizer_position

      validates :organizer_position, uniqueness: { scope: :event }
      validate :organizer_position_must_manage_event

      private

      def organizer_position_must_manage_event
        return if organizer_position.nil? || event.nil?

        manages_event = organizer_position.event_id == event_id || event.ancestor_ids.include?(organizer_position.event_id)
        return if organizer_position.manager? && manages_event

        errors.add(:organizer_position, "must be a manager of this organization")
      end

    end
  end

end
