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

      def create_transfer(event, **attr)

        wise_transfer = event.wise_transfers.build(
          amount_cents: payout_holding.amount_cents,
          address_line1: payout_method.address_line1,
          address_line2: payout_method.address_line2,
          address_city: payout_method.address_city,
          address_state: payout_method.address_state,
          address_postal_code: payout_method.address_postal_code,
          recipient_country: payout_method.recipient_country,
          currency: payout_method.currency,
          wise_recipient_id: payout_method.wise_recipient_id,
          recipient_information: payout_method.recipient_information
        )
        return wise_transfer
      end

    end

  end

end
