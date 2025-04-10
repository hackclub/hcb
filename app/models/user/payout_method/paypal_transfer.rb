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
      validates :recipient_email, format: { with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email address" }
      validates_presence_of :recipient_email
      normalizes :recipient_email, with: ->(recipient_email) { recipient_email.strip.downcase }

      validate do
        errors.add(:base, "Due to integration issues, transfers via PayPal are currently unavailable. Please choose another payout method.")
      end

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

    end
  end

end
