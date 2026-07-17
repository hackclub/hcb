# frozen_string_literal: true

# == Schema Information
#
# Table name: user_payout_method_wise_transfers
#
#  id                               :bigint           not null, primary key
#  address_city                     :string
#  address_line1                    :string
#  address_line2                    :string
#  address_postal_code              :string
#  address_state                    :string
#  bank_name                        :string
#  currency                         :string
#  recipient_country                :integer
#  recipient_information_ciphertext :text
#  created_at                       :datetime         not null
#  updated_at                       :datetime         not null
#  wise_recipient_id                :text
#
class LegalEntity
  class PayoutMethod < ApplicationRecord
    class WiseTransfer < ApplicationRecord
      self.table_name = "user_payout_method_wise_transfers"
      has_encrypted :recipient_information, type: :json

      include HasWiseRecipient

      validates_presence_of :address_line1, :address_city, :address_state, :address_postal_code, :recipient_country, :currency

      def self.permitted_attributes
        [:address_line1, :address_line2, :address_city, :address_state, :address_postal_code,
         :recipient_country, :currency] +
          recipient_information_accessors
      end

      def kind
        "wise_transfer"
      end

      def icon
        "wise"
      end

      def name
        "a Wise transfer"
      end

      def human_kind
        "Wise transfer"
      end

      def title_kind
        "Wise Transfer"
      end

      # See LegalEntity::PayoutMethod for the shared `create_transfer` contract.
      def create_transfer(event, amount:, payment_for:, recipient_name:, recipient_email:, user:, currency: "USD", bank_name: nil, **)
        usd_amount_cents = MoneyService.convert_to_usd(amount, currency)
        local_amount_cents = MoneyService.convert_from_usd(usd_amount_cents, self.currency)

        event.wise_transfers.build(
          address_line1:,
          address_line2:,
          address_city:,
          address_state:,
          address_postal_code:,
          recipient_country:,
          currency: self.currency,
          wise_recipient_id:,
          recipient_information:,
          amount_cents: local_amount_cents,
          payment_for:,
          recipient_name:,
          recipient_email:,
          user:,
          bank_name:
        )
      end

      def payout_summary
        ["wise transfer", ("to #{bank_name}" if bank_name.present?), ("(#{currency})" if currency.present?)].compact.join(" ")
      end

      def short_label
        currency.present? ? "#{title_kind} (#{currency})" : title_kind
      end

      def detail_summary
        if bank_name.present? && currency.present?
          "#{bank_name} (#{currency})"
        elsif bank_name.present?
          bank_name
        elsif currency.present?
          "Wise transfer (#{currency})"
        else
          "Wise transfer"
        end
      end

    end

  end

end
