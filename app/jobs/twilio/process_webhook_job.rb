# frozen_string_literal: true

module Twilio
  class ProcessWebhookJob < ApplicationJob
    queue_as :critical
    include Rails.application.routes.url_helpers

    def perform(webhook_params:)
      @params = webhook_params.with_indifferent_access
      @user = find_user
      @attachments = fetch_attachments
      @receiptable = find_receiptable
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
        send_reply("Attached #{receipts.count} #{"receipt".pluralize(receipts.count)} to #{@receiptable.memo}! #{hcb_code_url(@receiptable)}")
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

      user_id = last_sent_message_hcb_code&.canonical_pending_transactions&.last&.stripe_card&.user&.id
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

    def find_receiptable
      return nil if reimbursement?

      if last_sent_message_hcb_code && last_sent_message_hcb_code.pt.created_at > 5.minutes.ago
        last_sent_message_hcb_code
      end
    end

    def last_sent_message_hcb_code
      @last_sent_message_hcb_code ||= OutgoingTwilioMessage
                                      .joins(:twilio_message)
                                      .where("twilio_messages.to" => @params["From"])
                                      .where.not(hcb_code: nil)
                                      .last&.hcb_code
    end

    def find_reimbursement_report
      @user&.reimbursement_reports&.where(event_id: nil, updated_at: 24.hours.ago..)&.order(created_at: :desc)&.first
    end

    def reimbursement?
      @params["To"] == "+18023004260"
    end

  end
end
