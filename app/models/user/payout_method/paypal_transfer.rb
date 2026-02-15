# frozen_string_literal: true

# == Schema Information
#
# Table name: user_payout_method_paypal_transfers
#
#  id              :bigint           not null, primary key
#  recipient_email :text             not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
class User
  module PayoutMethod
    class PaypalTransfer < ApplicationRecord
      include Shared

      self.table_name = "user_payout_method_paypal_transfers"
      validates :recipient_email, email_with_tld: true
      validates_presence_of :recipient_email
      normalizes :recipient_email, with: ->(recipient_email) { recipient_email.strip.downcase }

      def kind
        "paypal_transfer"
      end

      def icon
        "paypal"
      end

      def name
        "a PayPal transfer"
      end

      def human_kind
        "PayPal"
      end

      def title_kind
        "PayPal"
      end

      def currency
        "USD"
      end

    end
  end

end
