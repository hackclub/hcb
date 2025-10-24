# frozen_string_literal: true

# == Schema Information
#
# Table name: governance_admin_transfer_approval_attempts
#
#  id                                   :bigint           not null, primary key
#  attempted_amount_cents               :integer          not null
#  current_limit_amount_cents           :integer          not null
#  current_limit_remaining_amount_cents :integer          not null
#  current_limit_used_amount_cents      :integer          not null
#  current_limit_window_ended_at        :datetime         not null
#  current_limit_window_started_at      :datetime         not null
#  denial_reason                        :string
#  result                               :string           not null
#  transfer_type                        :string           not null
#  created_at                           :datetime         not null
#  updated_at                           :datetime         not null
#  governance_admin_transfer_limit_id   :bigint           not null
#  governance_request_context_id        :bigint
#  transfer_id                          :bigint           not null
#  user_id                              :bigint           not null
#
# Indexes
#
#  idx_on_governance_admin_transfer_limit_id_3dfaba4d9a           (governance_admin_transfer_limit_id)
#  idx_on_governance_request_context_id_bec1adb1c2                (governance_request_context_id)
#  index_governance_admin_transfer_approval_attempts_on_transfer  (transfer_type,transfer_id)
#  index_governance_admin_transfer_approval_attempts_on_user_id   (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (governance_admin_transfer_limit_id => governance_admin_transfer_limits.id)
#  fk_rails_...  (governance_request_context_id => governance_request_contexts.id)
#  fk_rails_...  (user_id => users.id)
#
module Governance
  module Admin
    module Transfer
      class ApprovalAttempt < ApplicationRecord
        class DeniedError < Governance::Error; end

        has_paper_trail

        include Governance::Admin::Transfer::ApprovalAttempt::LimitSnapshot
        include Governance::Admin::Transfer::ApprovalAttempt::Decision
        include Governance::Admin::Transfer::ApprovalAttempt::Reporting

        belongs_to :limit,
                   class_name: "Governance::Admin::Transfer::Limit",
                   foreign_key: "governance_admin_transfer_limit_id",
                   inverse_of: :approval_attempts

        belongs_to :user
        belongs_to :transfer, polymorphic: true

        belongs_to :request_context, class_name: "Governance::RequestContext", foreign_key: "governance_request_context_id", optional: true

        monetize :attempted_amount_cents
        validates :attempted_amount_cents, numericality: { greater_than: 0 }
        validate :one_successful_approval_per_transfer, on: :create

        enum :result, {
          approved: "approved",
          denied: "denied"
        }
        DENIAL_REASONS = {
          # Reason lambdas should NOT contain any dynamic inputs. Please store
          # dynamic values as columns on the model so the lambda returns a
          # deterministic string.
          insufficient_limit: ->(attempt) do
            <<~STR.squish
              This transfer exceeds your limit of #{attempt.current_limit_amount.format}
              for the past #{ApplicationController.helpers.distance_of_time_in_words(Limit::WINDOW_DURATION)}
              (since #{attempt.current_limit_window_started_at}).
              You have #{attempt.current_limit_remaining_amount.format} remaining in your transfer limit."
            STR
          end,
        }.freeze
        enum :denial_reason, DENIAL_REASONS.map { |k, _v| [k, k.to_s] }.to_h, prefix: :denied_for

        def denial_message
          return if denial_reason.nil?

          DENIAL_REASONS[denial_reason.to_sym].call(self)
        end

        validates :denial_reason, absence: true, if: :approved?
        validate :user_matches_limit_user

        private

        def user_matches_limit_user
          return if user_id == limit.user_id

          errors.add(:user, "must match the user associated with the limit")
        end

        def one_successful_approval_per_transfer
          # The goal here is to prevent users from eating up their transfer
          # limits by approving the same transfer multiple times.
          return if ApprovalAttempt.where(transfer:, result: :approved).none?

          errors.add(:transfer, "was already approved!")
        end

      end
    end
  end
end
