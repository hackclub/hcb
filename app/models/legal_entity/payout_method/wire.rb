# frozen_string_literal: true

# == Schema Information
#
# Table name: user_payout_method_wires
#
#  id                        :bigint           not null, primary key
#  account_number_bidx       :string           not null
#  account_number_ciphertext :string           not null
#  address_city              :string
#  address_line1             :string
#  address_line2             :string
#  address_postal_code       :string
#  address_state             :string
#  bic_code_bidx             :string           not null
#  bic_code_ciphertext       :string           not null
#  recipient_country         :integer
#  recipient_information     :jsonb
#  recipient_name            :string
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#
class LegalEntity
  class PayoutMethod < ApplicationRecord
    class Wire < ApplicationRecord
      self.table_name = "user_payout_method_wires"

      has_encrypted :account_number, :bic_code
      blind_index :account_number, :bic_code

      include HasWireRecipient

      def self.permitted_attributes
        [:address_line1, :address_line2, :address_city, :address_state, :address_postal_code,
         :recipient_country, :recipient_name, :bic_code, :account_number] +
          recipient_information_accessors
      end

      def kind
        "international_wire"
      end

      def icon
        "web"
      end

      def name
        "an international wire"
      end

      def human_kind
        "international wire"
      end

      def title_kind
        "International Wire"
      end

      def payout_summary
        "international wire to account ending in ••••#{account_number.to_s.last(4)}"
      end

      def short_label
        last4 = account_number.to_s.last(4) if account_number.to_s.size >= 8
        last4.present? ? "Wire (••••#{last4})" : "Wire"
      end

      def detail_summary
        last4 = account_number.to_s.last(4) if account_number.to_s.size >= 8
        last4.present? ? "Account ••••#{last4}" : "Wire transfer"
      end

      def currency
        "USD"
      end

      # See LegalEntity::PayoutMethod for the shared `create_transfer` contract.
      def create_transfer(event, amount:, payment_for:, recipient_email:, user:, recipient_name:, memo:, send_email_notification: false, **)
        event.wires.build(
          address_line1:,
          address_line2:,
          address_city:,
          address_state:,
          address_postal_code:,
          recipient_country:,
          account_number:,
          bic_code:,
          recipient_information: recipient_information.merge({
                                                               purpose_code: Wire.reimbursement_purpose_code_for(recipient_country),
                                                               remittance_info: Wire.reimbursement_remittance_info_for(recipient_country),
                                                             }),
          amount_cents: amount,
          recipient_name: self.recipient_name.presence || recipient_name,
          recipient_email:,
          payment_for: payment_for&.slice(0...140),
          memo:,
          user:,
          currency:,
          send_email_notification:,
        )
      end

    end

  end

end
