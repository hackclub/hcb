# frozen_string_literal: true

# == Schema Information
#
# Table name: organizer_position_spending_controls
#
#  id                    :bigint           not null, primary key
#  active                :boolean          default(TRUE)
#  ended_at              :datetime
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  organizer_position_id :bigint           not null
#
# Indexes
#
#  idx_org_pos_spend_ctrls_on_org_pos_id  (organizer_position_id)
#
# Foreign Keys
#
#  fk_rails_...  (organizer_position_id => organizer_positions.id)
#
class OrganizerPosition
  module Spending
    class Control < ApplicationRecord
      belongs_to :organizer_position
      has_many :allowances,
               class_name: "OrganizerPosition::Spending::Control::Allowance",
               foreign_key: "organizer_position_spending_control_id",
               dependent: :destroy,
               inverse_of: :control

      validate :one_active_control
      validate :inactive_control_has_end_date

      after_create :deactive_other_controls

      def balance_cents
        total_allowances_amount_cents - total_spent_cents
      end

      def total_allowances_amount_cents
        allowances.sum(:amount_cents)
      end

      def total_spent_cents
        transactions.sum(&:amount_cents) * -1
      end

      def transactions
        card_ids = organizer_position.stripe_cards.pluck(:stripe_id)
        canonical_pending_transactions_hcb_codes = CanonicalPendingTransaction
                                                   .not_declined
                                                   .joins(:raw_pending_stripe_transaction)
                                                   .where("(stripe_transaction->'card'->>'id' IN (?)) AND (CAST(stripe_transaction->>'created' AS BIGINT) BETWEEN ? AND ?)", card_ids, created_at.to_i, ended_at&.to_i || Time.now.to_i)
                                                   .pluck(:hcb_code)
        canonical_transactions_hcb_codes = CanonicalTransaction
                                           .stripe_transaction
                                           .where("(stripe_transaction->'card'->>'id' IN (?)) AND (CAST(stripe_transaction->>'created' AS BIGINT) BETWEEN ? AND ?)", card_ids, created_at.to_i, ended_at&.to_i || Time.now.to_i)
                                           .pluck(:hcb_code)
        all_hcb_codes = canonical_pending_transactions_hcb_codes + canonical_transactions_hcb_codes
        HcbCode.where(hcb_code: all_hcb_codes)
      end

      def deactivate
        if allowances.count == 0
          destroy
        else
          update active: false, ended_at: Time.current
        end
      end

      private

      def deactive_other_controls
        organizer_position
          .spending_controls
          .where(active: true)
          .excluding(self)
          .update_all(active: false, ended_at: Time.current)
      end

      def one_active_control
        if organizer_position.spending_controls.where(active: true).size > 1
          errors.add(:organizer_position, "may only have one active spending control")
        end
      end

      def inactive_control_has_end_date
        if !active && ended_at.nil?
          errors.add(:ended_at, "must exist for inactive controls")
        end
      end

    end
  end

end
