# frozen_string_literal: true

module ReceiptReport
  class SendJob < ApplicationJob
    queue_as :low
    def perform(user_id)
      @user = User.includes(:stripe_cards).find user_id

      return unless hcb_ids.any?

      mailer = ReceiptableMailer.with(user_id:,
                                      hcb_ids:)

      mailer.receipt_report.deliver_later
    end

    def hcb_ids
      @hcb_ids ||= begin
        @user.hcb_code_ids_missing_receipt
      end
    end

  end
end
