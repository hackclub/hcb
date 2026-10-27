# frozen_string_literal: true

# == Schema Information
#
# Table name: event_reimbursement_reviewer_opt_outs
#
#  id                    :bigint           not null, primary key
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  organizer_position_id :bigint           not null
#
# Indexes
#
#  idx_on_organizer_position_id_573124f7b8  (organizer_position_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (organizer_position_id => organizer_positions.id)
#
class Event
  # A manager who doesn't review reimbursement reports without an assigned
  # reviewer. The opt-out follows their organizer position, so it also covers
  # the sub-organizations that position gives them access to.
  class ReimbursementReviewerOptOut < ApplicationRecord
    has_paper_trail

    belongs_to :organizer_position
    has_one :event, through: :organizer_position
    has_one :user, through: :organizer_position

    validates :organizer_position, uniqueness: true
    validate :organizer_position_must_be_manager

    private

    def organizer_position_must_be_manager
      return if organizer_position.nil? || organizer_position.manager?

      errors.add(:organizer_position, "must be a manager")
    end

  end

end
