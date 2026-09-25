# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReceiptBinMailbox do
  include ActionMailbox::TestHelper
  include ActionMailer::TestHelper
  # The helpers above expect a tagged_logger method to be present
  # See https://github.com/rspec/rspec-rails/issues/2545
  attr_reader(:tagged_logger)

  def receive_email(to:, from:, cc: nil)
    receive_inbound_email_from_mail(
      to:,
      from:,
      cc:,
      subject: "Receipt",
      body: <<~BODY,
        Receipt attached
      BODY
      attachments: {
        "logo.png" => File.read(Rails.root.join("public/logo.png"))
      }
    )
  end

  # An email forwarded *as an attachment* (Gmail's "Forward as attachment",
  # which is how people bulk-send a backlog of receipts in), carrying its own
  # receipt attachment.
  def forwarded_as_attachment_email(to:, from:)
    original = Mail.new do
      to "me@example.com"
      from "billing@vendor.com"
      subject "Your receipt"
      html_part do
        content_type "text/html; charset=UTF-8"
        body "<p>Thanks for your order! Total $12.34</p>"
      end
      add_file filename: "logo.png", content: File.read(Rails.root.join("public/logo.png"))
    end

    forward = Mail.new(to:, from:, subject: "Fwd: Your receipt", body: "See attached")
    forward.add_file(filename: "Your receipt.eml", content: original.to_s)
    forward.parts.last.content_type = 'message/rfc822; name="Your receipt.eml"'

    forward
  end

  before do
    extract_service = instance_double(ReceiptService::Extract)
    expect(extract_service).to receive(:run!).and_return(nil)
    expect(ReceiptService::Extract).to receive(:new).and_return(extract_service)
  end

  context "with generic addresses" do
    it "finds the user based on the from address" do
      user = create(:user, email: "test@example.com")

      sent_emails = capture_emails do
        receive_email(to: "receipts@hackclub.com", from: user.email)
      end

      expect(user.receipts.count).to eq(1)

      confirmation_email = sent_emails.sole
      expect(confirmation_email.to).to contain_exactly(user.email)
      expect(confirmation_email.text_part.body.to_s).to include("We got your receipt")
    end

    it "supports CCs" do
      user = create(:user, email: "test@example.com")

      sent_emails = capture_emails do
        receive_email(
          to: "hack-clubber@example.com",
          cc: "receipts@hcb.gg",
          from: user.email
        )
      end

      expect(user.receipts.count).to eq(1)

      confirmation_email = sent_emails.sole
      expect(confirmation_email.to).to contain_exactly(user.email)
      expect(confirmation_email.text_part.body.to_s).to include("We got your receipt")
    end
  end

  context "with an email forwarded as an attachment" do
    it "files the forwarded receipt once, not alongside a render of its body" do
      user = create(:user, email: "test@example.com")

      capture_emails do
        receive_inbound_email_from_source(
          forwarded_as_attachment_email(to: "receipts@hackclub.com", from: user.email).to_s
        )
      end

      # Both the attachment and a PDF of the forwarded body would be the same
      # receipt. The extra copy is what gets stranded in the receipt bin once
      # the first one is auto-matched to a transaction.
      expect(user.receipts.count).to eq(1)
      expect(user.receipts.sole.file.blob.filename.to_s).to eq("logo.png")
    end
  end

  context "with a mailbox address" do
    it "finds the user based on the mailbox address" do
      user = create(:user, email: "test@example.com")
      mailbox_address = user.mailbox_addresses.create!
      mailbox_address.mark_activated!

      sent_emails = capture_emails do
        receive_email(to: mailbox_address.address, from: "not-user@example.com")
      end

      expect(user.receipts.count).to eq(1)

      confirmation_email = sent_emails.sole
      expect(confirmation_email.to).to contain_exactly("not-user@example.com")
      expect(confirmation_email.text_part.body.to_s).to include("We got your receipt")
    end

    it "supports CCs" do
      user = create(:user, email: "test@example.com")
      mailbox_address = user.mailbox_addresses.create!
      mailbox_address.mark_activated!

      sent_emails = capture_emails do
        receive_email(
          to: "hack-clubber@example.com",
          cc: mailbox_address.address,
          from: "not-user@example.com"
        )
      end

      expect(user.receipts.count).to eq(1)

      confirmation_email = sent_emails.sole
      expect(confirmation_email.to).to contain_exactly("not-user@example.com")
      expect(confirmation_email.text_part.body.to_s).to include("We got your receipt")
    end
  end
end
