# == Schema Information
#
# Table name: organizer_position_spending_controls
#
#  id                    :bigint           not null, primary key
#  active                :boolean
#  ended_at              :datetime
#  started_at            :datetime
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
      has_many :organizer_position_spending_allowances, class_name: "OrganizerPosition::Spending::Allowance", foreign_key: "organizer_position_spending_control_id", dependent: :destroy

      validate :one_active_control
      validate :inactive_control_has_end_date

      after_create :deactive_other_controls

      def balance
        total_allocation_amount - total_spent
      end

      def total_allocation_amount
        organizer_position_spending_allowances.sum(:amount_cents)
      end


      def total_spent
        transactions.map(&:amount_cents).sum.abs
      end

      def transactions
        card_ids = organizer_position.stripe_cards.pluck(:stripe_id)
        RawPendingStripeTransaction.pending.where("(stripe_transaction->'card'->>'id' IN (?)) AND (CAST(stripe_transaction->>'created' AS BIGINT) BETWEEN EXTRACT(EPOCH FROM TIMESTAMP ?) AND EXTRACT(EPOCH FROM TIMESTAMP ?))", card_ids, created_at, (ended_at || Float::INFINITY))
                                   .includes(:canonical_pending_transaction)
                                   .map(&:canonical_pending_transaction)
      end

      private

      def deactive_other_controls
        organizer_position.spending_controls.where(active: true).excluding(self).update_all(active: false, ended_at: Time.current)
      end

      def one_active_control
        if organizer_position.spending_controls.where(active: true).size > 1
          errors.add(:organizer_position, "may only have one active spending control")
        end
      end

      def inactive_control_has_end_date
        if !active && ended_at.nil?
          errors.add(:ended_at, "inactive controls must have an ended_at date")
        end
      end

    end
  end

end
