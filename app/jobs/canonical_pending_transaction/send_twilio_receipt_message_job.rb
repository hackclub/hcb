# frozen_string_literal: true

class CanonicalPendingTransaction
  class SendTwilioReceiptMessageJob < ApplicationJob
    queue_as :critical
    include HcbCodeHelper # for attach_receipt_url

    def perform(cpt_id:, user_id:)
      @cpt = CanonicalPendingTransaction.find(cpt_id)
      @user = User.find(user_id)


      return unless @user.phone_number.present? && @user.phone_number_verified?

      hcb_code = @cpt.local_hcb_code
      message = "Your card was charged $#{@cpt.amount.abs} at '#{@cpt.memo}'."
      if hcb_code.receipt_required?
        message += " To attach a receipt, text us a image in the next five minutes, or upload one to #{attach_receipt_url hcb_code}."
      end

      TwilioMessageService::Send.new(@user, message, hcb_code:).run!
    end

    discard_on(Twilio::REST::RestError) do |job, error|
      Rails.error.report(error) unless User.find(job.arguments.first[:user_id]).phone_number.starts_with?("+44") # we can't send text messages to the UK
    end

  end

end
