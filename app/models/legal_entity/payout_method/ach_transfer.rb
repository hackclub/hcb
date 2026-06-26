# frozen_string_literal: true

# == Schema Information
#
# Table name: user_payout_method_ach_transfers
#
#  id                        :bigint           not null, primary key
#  account_number_ciphertext :text             not null
#  routing_number_ciphertext :text             not null
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#
class LegalEntity
  class PayoutMethod < ApplicationRecord
    class AchTransfer < ApplicationRecord
      self.table_name = "user_payout_method_ach_transfers"
      has_encrypted :account_number, :routing_number
      validates :routing_number, format: { with: /\A\d{9}\z/, message: "must be 9 digits" }
      validates :account_number, format: { with: /\A\d+\z/, message: "must be only numbers" }

      def kind
        "ach_transfer"
      end

      def icon
        "bank-account"
      end

      def name
        "an ACH transfer"
      end

      def human_kind
        "ACH transfer"
      end

      def title_kind
        "ACH Transfer"
      end

      def currency
        "USD"
      end

      def create_transfer(event, **attr)
        ach_transfer = clearinghouse.ach_transfers.build(
          amount: payout_holding.amount_cents,
          recipient_name: payout_holding.report.user.full_name,
          recipient_email: payout_holding.report.user.email,
          routing_number: payout_method.routing_number,
          account_number: payout_method.account_number,
          **attr
        )
        return ach_transfer
      end

    end

  end

end
