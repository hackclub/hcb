# frozen_string_literal: true

module ReceiptReport
  class SendJob < ApplicationJob
    queue_as :low
    def perform(user_id)
      @user = User.find user_id

      return unless ledger_item_ids.any?

      mailer = ReceiptableMailer.with(user_id:,
                                      ledger_item_ids:)

      mailer.receipt_report.deliver_later
    end

    def ledger_item_ids
      @ledger_item_ids ||= @user.card_charges_missing_receipt.pluck(:id)
    end

  end
end
