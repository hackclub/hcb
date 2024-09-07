# frozen_string_literal: true

module Reimbursement
  class MailboxMailer < ApplicationMailer
    before_action { @inbound_mail = params[:mail] }
    before_action { @reply_to = params[:reply_to] }
    before_action { @to = params[:to] || @inbound_mail&.mail&.from&.first }

    default to: -> { @to },
            reply_to: -> { @reply_to },
            subject: -> { @inbound_mail&.mail&.subject },
            in_reply_to: -> { @inbound_mail&.message_id },
            references: -> { [@inbound_mail&.mail&.header&.[]("References")&.value, @inbound_mail&.message_id].compact.join(" ") }

    def bounce_missing_user
      mail subject: @inbound_mail&.mail&.subject || "Unknown Receipt Bin inbox"
    end

    def bounce_missing_attachment
      mail subject: @inbound_mail&.mail&.subject || "Missing attachment(s)"
    end

    def bounce_success
      @report = params[:report]
      @receipts_count = params[:receipts_count]
      mail subject: @inbound_mail&.mail&.subject || "We've created your reimbursement report!"
    end

    def bounce_error
      mail subject: @inbound_mail&.mail&.subject || "An unknown error occured"
    end


  end
end
