# == Schema Information
#
# Table name: governance_admin_transfer_limits
#
#  id           :bigint           not null, primary key
#  amount_cents :integer          not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  user_id      :bigint           not null
#
# Indexes
#
#  index_governance_admin_transfer_limits_on_user_id  (user_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
module Governance
  module Admin
    module Transfer
      class Limit < ApplicationRecord
        WINDOW_DURATION = 1.day

        class MissingApprovalLimitError < Governance::Error; end

        has_paper_trail

        belongs_to :user

        has_many :approval_attempts,
                 class_name: "Governance::Admin::Transfer::ApprovalAttempt",
                 foreign_key: "governance_admin_transfer_limit_id",
                 inverse_of: :limit

        monetize :amount_cents
        validates :amount_cents, presence: true, numericality: { greater_than_or_equal_to: 0 }

        validates :user, uniqueness: true
        validate :user_is_admin, on: :create

        monetize def used_amount_cents
          approval_attempts.approved.where(created_at: self.class.current_window).sum(:attempted_amount_cents)
        end

        monetize def remaining_amount_cents = amount_cents - used_amount_cents

        def self.current_window
          current_window_started_at..current_window_ended_at
        end

        def self.current_window_started_at = WINDOW_DURATION.ago

        def self.current_window_ended_at = Time.current

        private

        def user_is_admin
          return if user.admin?(override_pretend: true)

          errors.add(:user, "must be an admin")
        end

      end
    end
  end
end
