# frozen_string_literal: true

class ApplicationMailbox < ActionMailbox::Base
  # routing /something/i => :somewhere

  # Routing all the incoming emails to the HcbCode Mailbox
  # ie. "receipts+hcb-123abc@hcb.hackclub.com" for HcbCodes
  routing ->(inbound_email) { inbound_email.mail.to&.first&.match?(/^receipts\+/i) } => :hcb_code
  routing ->(inbound_email) { inbound_email.mail.to&.first&.match?(/^comments\+/i) } => :comment

  # ie. "animal.1234" for Users
  routing /#{MailboxAddress::VALIDATION_REGEX}/i => :receipt_bin

  # receipts@hcb.hackclub.com or receipts@hcb.gg
  routing /^receipts/i => :receipt_bin

  # reimburse@hcb.hackclub.com or reimbursements@hcb.hackclub.com
  routing /^reimburse/i => :reimbursement

  # fallback
  routing all: :fallback

  # Helper methods
  private

  # Part#decoded converts the part's charset to UTF-8; body.decoded returns raw bytes.
  def html
    mail.html_part&.decoded
  end

  def text
    mail.text_part&.decoded
  end

  def body
    mail.decoded.presence unless mail.multipart?
  end

end
