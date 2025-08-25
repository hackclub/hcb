class User
  module PayoutMethod
    class WiseTransfer < ApplicationRecord
      self.table_name = "user_payout_method_wires"
      has_one :user, inverse_of: :payout_method, as: :payout_method
      has_encrypted :recipient_information, type: :json

      include HasWiseRecipient

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

    end
  end

end
