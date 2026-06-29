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

      # See LegalEntity::PayoutMethod for the shared `create_transfer` contract.
      def create_transfer(event, amount:, payment_for:, recipient_name:, recipient_email:, user:, company_entry_description: nil, send_email_notification: false, **)
        bank_name = ColumnService.get("/institutions/#{routing_number}")["full_name"] rescue "Bank Account"

        event.ach_transfers.build(
          routing_number:,
          account_number:,
          creator: user,
          amount:,
          bank_name:,
          payment_for:,
          recipient_name:,
          recipient_email:,
          company_entry_description:,
          send_email_notification:,
        )
      end

    end

  end

end
