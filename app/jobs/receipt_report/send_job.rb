# frozen_string_literal: true

module ReceiptReport
  class SendJob < ApplicationJob
    queue_as :default
    def perform(user_id, force_send: false)
      @user = User.includes(:stripe_cards).find user_id

      return unless force_send ||
                    @user.receipt_report_weekly? ||
                    @user.receipt_report_monthly?
      return unless hcb_ids.any?

      mailer = ReceiptableMailer.with(user_id:,
                                      hcb_ids:)

      mailer.receipt_report.deliver_later
    end

    def hcb_ids
      @hcb_ids ||= begin
        @user.stripe_cards.flat_map do |card|
          card.hcb_codes.missing_receipt.receipt_required.pluck(:id)
        end
      end
    end

  end
end

module ReceiptReportJob
  Send = ReceiptReport::SendJob
end
