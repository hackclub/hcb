# frozen_string_literal: true

module Twilio
  class ProcessWebhookJob < ApplicationJob
    queue_as :critical
    include Rails.application.routes.url_helpers

    def perform(webhook_params:)
      @params = webhook_params.with_indifferent_access
      @user = find_user
      @attachments = fetch_attachments
      @ledger_item = find_ledger_item
      @receiptable = @ledger_item
      @report = find_reimbursement_report

      if @user.nil?
        send_reply(<<~MSG.squish)
          Hey! We couldn't find your account on HCB; if you're looking to upload
          receipts, make sure your phone number is set and verified in your account's settings
          (https://hcb.hackclub.com/my/settings).
        MSG
        return
      end

      if reimbursement?
        @report ||= @user.reimbursement_reports.create(inviter: @user)
        @receiptable = @report.expenses.create!(amount_cents: 0)
      end

      if @attachments.none?
        send_reply(<<~MSG.squish)
          Hey! Are you trying to upload receipts? We couldn't find any attachments in your message.
          If you're looking for HCB support, please reach out to hcb@hackclub.com.
        MSG
        return
      end

      receipts = ::ReceiptService::Create.new(
        receiptable: @receiptable,
        uploader: @user,
        attachments: @attachments,
        upload_method: reimbursement? ? "sms_reimbursement" : "sms"
      ).run!

      if reimbursement? && receipts.first.suggested_memo
        @receiptable.update(memo: receipts.first.suggested_memo, value: receipts.first.extracted_total_amount_cents.to_f / 100)
      end

      if reimbursement? && @report.previously_new_record?
        send_reply("Attached #{receipts.count} #{"receipt".pluralize(receipts.count)} to a new reimbursement report! #{reimbursement_report_url(@report)}")
      elsif reimbursement?
        send_reply("Attached #{receipts.count} #{"receipt".pluralize(receipts.count)} to your report named: #{@report.name}! #{reimbursement_report_url(@report)}")
      elsif @receiptable
        send_reply("Attached #{receipts.count} #{"receipt".pluralize(receipts.count)} to #{@ledger_item.memo}! #{ledger_item_url(@ledger_item)}")
      else
        send_reply("Added #{receipts.count} #{"receipt".pluralize(receipts.count)} to your Receipt Bin! https://hcb.hackclub.com/my/inbox")
      end
    end

    private

    def send_reply(message)
      TwilioMessageService::Send.new(@user, message, phone_number: @params["From"]).run!
    end

    def find_user
      potential_users = User.where(phone_number: @params["From"], phone_number_verified: true)
      return potential_users.first if potential_users.count == 1

      user_id = last_sent_message&.ledger_item&.canonical_pending_transactions&.last&.stripe_card&.user&.id
      potential_users.find_by(id: user_id)
    end

    def fetch_attachments
      num_media = @params["NumMedia"].to_i
      return [] if num_media.zero?

      (0..num_media - 1).map do |i|
        uri = URI.parse(@params["MediaUrl#{i}"])
        break unless ["http", "https"].include?(uri.scheme)

        {
          filename: "SMS_#{Time.now.strftime("%Y-%m-%d-%H:%M")}",
          content_type: @params["MediaContentType#{i}"],
          io: uri.open
        }
      end
    end

    def find_ledger_item
      return nil if reimbursement?

      # The window is measured from when we texted, so a re-sent SMS for an older charge still gets all of it.
      # Decline texts carry a ledger item too but never ask for a receipt, hence `receipt_required?`.
      charges = sent_messages.where(created_at: OutgoingTwilioMessage::RECEIPT_REPLY_WINDOW.ago..)
                             .includes(:ledger_item).map(&:ledger_item).uniq.select(&:receipt_required?)

      # With several charges in the window, the photo is for the one still missing a receipt.
      # If that doesn't settle it, the photo goes to the Receipt Bin rather than the wrong charge.
      charges = charges.select(&:missing_receipt?) if charges.many?
      charges.first if charges.one?
    end

    def sent_messages
      OutgoingTwilioMessage
        .joins(:twilio_message)
        .where("twilio_messages.to" => @params["From"])
        .where.not(ledger_item: nil)
    end

    def last_sent_message
      @last_sent_message ||= sent_messages.last
    end

    def find_reimbursement_report
      @user&.reimbursement_reports&.where(event_id: nil, updated_at: 24.hours.ago..)&.order(created_at: :desc)&.first
    end

    def reimbursement?
      @params["To"] == "+18023004260"
    end

  end
end
