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

        belongs_to :request_context, class_name: "Governance::RequestContext", foreign_key: "governance_request_context_id", optional: true, inverse_of: false

        monetize :attempted_amount_cents
        validates :attempted_amount_cents, numericality: { greater_than: 0 }
        validate :one_successful_approval_per_transfer, on: :create

        SUCCESS_STATES = %i[approved redundantly_approved].freeze
        enum :result, {
          approved: "approved",
          redundantly_approved: "redundantly_approved",
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
          impersonation: ->(attempt) do
            <<~STR.squish
              **sniff sniff** 👃 You don't smell very much like
              #{attempt.user.name || "the current user"}.
              Please end your impersonation session and try again 😉.
            STR
          end
        }.freeze
        enum :denial_reason, DENIAL_REASONS.map { |k, _v| [k, k.to_s] }.to_h, prefix: :denied_for

        def denial_message
          return if denial_reason.nil?

          DENIAL_REASONS[denial_reason.to_sym].call(self)
        end

        validates :denial_reason, absence: true, if: :approved?
        validate :user_matches_limit_user

        delegate :impersonator, :impersonated?, to: :request_context, allow_nil: true

        def successful?
          SUCCESS_STATES.include?(result.to_sym)
        end

        def previously_approved_attempt
          # There theoretically could only be one
          ApprovalAttempt.find_by(transfer:, user:, result: :approved)
        end

        def previously_approved?
          previously_approved_attempt.present?
        end

        private

        def user_matches_limit_user
          return if user_id == limit.user_id

          errors.add(:user, "must match the user associated with the limit")
        end

        def one_successful_approval_per_transfer
          # The goal here is to prevent users from eating up their transfer
          # limits by approving the same transfer multiple times.
          #
          # Different users should be able to approve the same transfer
          # independently; we do this primarily for logging purposes. This may
          # happen if the first approval succeeds, but transfer isn't sent due
          # to validation/network errors. Then, a second person attempts it.
          if previously_approved? && approved?
            Rails.error.unexpected("Detected multiple successful approval attempts for the same transfer. Ensure second approvals are marked as `redundantly_approved`.")
            errors.add(:transfer, "was already approved! Report this issue to an engineer.")
          end
        end

      end
    end
  end
end
