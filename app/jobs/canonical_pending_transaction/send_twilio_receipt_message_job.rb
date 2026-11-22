# frozen_string_literal: true

class CanonicalPendingTransaction
  class SendTwilioReceiptMessageJob < ApplicationJob
    queue_as :critical

    include HcbCodeHelper

    def perform(cpt_id:, user_id:)
      @cpt = CanonicalPendingTransaction.find(cpt_id)
      @user = User.find(user_id)


      return unless @user.phone_number.present? && @user.phone_number_verified?

      ledger_item = @cpt.ledger_item
      message = "Your card was charged $#{@cpt.amount.abs} at '#{@cpt.memo}'."
      if ledger_item.receipt_required?
        message += " To attach a receipt, text us an image within ten minutes, or upload one to #{short_attach_receipt_url @cpt.local_hcb_code}."
      end

      TwilioMessageService::Send.new(@user, message, ledger_item:).run!
    end

  end

end
