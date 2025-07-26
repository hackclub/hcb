# frozen_string_literal: true

class ReceiptBinMailer < ApplicationMailer
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
    @receipts_count = params[:receipts_count]
    mail subject: @inbound_mail&.mail&.subject || "Thank you for your #{"receipt".pluralize(@receipts_count)}!"
  end

  def bounce_error
    mail subject: @inbound_mail&.mail&.subject || "An unknown error occured"
  end

  def paired
    @suggested_pairing = params[:suggested_pairing]
    mail subject: "We've paired your receipt with a transaction", to: @suggested_pairing.receipt.user.email, reply_to: @suggested_pairing.hcb_code.receipt_upload_email
  end

end
