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
        # `AchTransfer` always pays out in USD (no `currency`), has no memo,
        # tracks the sender as `creator`, and requires a `bank_name`.
        currency = attr.delete(:currency)
        attr[:amount] = MoneyService.convert_to_usd(attr[:amount], currency) if currency && attr[:amount]
        attr.delete(:memo)
        creator = attr.delete(:user) || attr.delete(:creator)
        attr[:bank_name] ||= ColumnService.get("/institutions/#{routing_number}")["full_name"] rescue "Bank Account"

        event.ach_transfers.build(
          routing_number:,
          account_number:,
          creator:,
          **attr
        )
      end

    end

  end

end
