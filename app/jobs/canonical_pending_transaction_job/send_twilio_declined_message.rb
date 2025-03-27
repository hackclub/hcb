# frozen_string_literal: true

module CanonicalPendingTransactionJob
  class SendTwilioDeclinedMessage < ApplicationJob
    queue_as :critical
    # This is a heuristic to avoid sending SMS for online charges. This isn't
    # always correct.
    IN_PERSON_AUTH_METHODS = %w[keyed_in swipe chip contactless].freeze

    def perform(cpt_id:, user_id:)
      @cpt = CanonicalPendingTransaction.find(cpt_id)
      @rpst = @cpt.raw_pending_stripe_transaction
      @card = @rpst.stripe_card
      @merchant = @rpst.stripe_transaction["merchant_data"]["name"]
      @reason = @rpst.stripe_transaction["request_history"][0]&.[]("reason")
      @webhook_declined_reason = @rpst.stripe_transaction.dig("metadata", "declined_reason")
      @user = User.find(user_id)

      return unless Flipper.enabled?(:sms_receipt_notifications_2022_11_23, @user)

      return unless IN_PERSON_AUTH_METHODS.include? auth_method

      return unless @user.phone_number.present? && @user.phone_number_verified?

      humanized_reason = case @reason
                         when "card_inactive"
                           if !@card.initially_activated?
                             "at #{@merchant} because this card hasn't been activated yet"
                           else
                             "at #{@merchant} because this card has been frozen"
                           end
                         when "suspected_fraud"
                           "at #{@merchant} due to suspected fraud"
                         when "webhook_declined"
                           case @webhook_declined_reason
                           when "merchant_not_allowed"
                             "because this card isn't allowed to make purchases at #{@merchant}"
                           when "cash_withdrawals_not_allowed"
                             "because cash withdrawals are not enabled on it"
                           else
                             "at #{@merchant} due to insufficient funds"
                           end
                         else
                           "at #{@merchant}"
                         end

      hcb_code = @cpt.local_hcb_code
      message = "Your card was declined just now #{humanized_reason}."

      TwilioMessageService::Send.new(@user, message, hcb_code:).run!
    end

    private

    def auth_method
      @cpt.raw_pending_stripe_transaction.authorization_method
    end

  end
end
