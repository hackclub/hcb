# frozen_string_literal: true

# == Schema Information
#
# Table name: event_reimbursement_reviewer_opt_outs
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  event_id   :bigint           not null
#  user_id    :bigint           not null
#
# Indexes
#
#  idx_on_event_id_user_id_5edc6f2c15                      (event_id,user_id) UNIQUE
#  index_event_reimbursement_reviewer_opt_outs_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#  fk_rails_...  (user_id => users.id)
#
class Event
  # A manager who doesn't review reimbursement reports without an assigned reviewer
  class ReimbursementReviewerOptOut < ApplicationRecord
    has_paper_trail

    belongs_to :event
    belongs_to :user

    validates :user, uniqueness: { scope: :event }
    validate :user_must_be_manager

    private

    def user_must_be_manager
      return if event.nil? || user.nil?

      unless event.ancestor_organizer_positions.manager_access.where(user:).exists?
        errors.add(:user, "must be a manager of this organization")
      end
    end

  end

end
