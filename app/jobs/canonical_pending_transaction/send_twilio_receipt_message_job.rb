# frozen_string_literal: true

class CanonicalPendingTransaction
  class SendTwilioReceiptMessageJob < ApplicationJob
    queue_as :critical
    include HcbCodeHelper # for attach_receipt_url

    # This is a heuristic to avoid sending SMS for online charges. This isn't
    # always correct.
    IN_PERSON_AUTH_METHODS = %w[keyed_in swipe chip contactless].freeze

    def perform(cpt_id:, user_id:)
      @cpt = CanonicalPendingTransaction.find(cpt_id)
      @user = User.find(user_id)

      return unless Flipper.enabled?(:sms_receipt_notifications_2022_11_23, @user)

      return unless IN_PERSON_AUTH_METHODS.include? auth_method

      return unless @user.phone_number.present? && @user.phone_number_verified?

      hcb_code = @cpt.local_hcb_code
      message = "Your card was charged $#{@cpt.amount.abs} at '#{@cpt.memo}'."
      if hcb_code.receipt_required?
        message += " To attach a receipt, text us a image in the next five minutes, or upload one to #{attach_receipt_url hcb_code}."
      end

      TwilioMessageService::Send.new(@user, message, hcb_code:).run!
    end

    discard_on(Twilio::REST::RestError) do |job, error|
      Airbrake.notify(error) unless User.find(job.arguments.first[:user_id]).phone_number.starts_with?("+44") # we can't send text messages to the UK
    end

    private

    def auth_method
      @cpt&.raw_pending_stripe_transaction&.authorization_method
    end

  end

end
