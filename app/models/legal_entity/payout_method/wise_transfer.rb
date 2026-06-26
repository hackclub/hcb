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
        # `WiseTransfer` stores the amount in `amount_cents`, generates its own
        # memo, and pays out in the recipient's own configured currency, so the
        # passed-in `memo` and `currency` are dropped.
        amount_cents = attr.delete(:amount)
        attr.delete(:memo)
        attr.delete(:currency)

        event.wise_transfers.build(
          address_line1:,
          address_line2:,
          address_city:,
          address_state:,
          address_postal_code:,
          recipient_country:,
          currency:,
          wise_recipient_id:,
          recipient_information:,
          amount_cents:,
          **attr
        )
      end

    end

  end

end
