# frozen_string_literal: true

# == Schema Information
#
# Table name: event_reimbursement_reviewers
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  event_id   :bigint           not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_event_reimbursement_reviewers_on_event_id_and_user_id  (event_id,user_id) UNIQUE
#  index_event_reimbursement_reviewers_on_user_id               (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_id => events.id)
#  fk_rails_...  (user_id => users.id)
#
class Event
  class ReimbursementReviewer < ApplicationRecord
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
