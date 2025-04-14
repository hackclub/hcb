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
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#
class User
  module PayoutMethod
    class Wire < ApplicationRecord
      self.table_name = "user_payout_method_wires"
      has_one :user, inverse_of: :payout_method, as: :payout_method
      after_save_commit -> { Reimbursement::PayoutHolding.where(report: user.reimbursement_reports).failed.each(&:mark_settled!) }
      has_encrypted :account_number, :bic_code
      blind_index :account_number, :bic_code

      include HasWireRecipient

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

    end
  end

end
