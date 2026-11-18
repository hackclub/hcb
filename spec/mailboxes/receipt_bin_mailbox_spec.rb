# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReceiptBinMailbox do
  before { allow(CloudflareBrowserRun).to receive(:pdf).and_return("%PDF-1.4") }

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

  before do
    extract_service = instance_double(ReceiptService::Extract)
    allow(extract_service).to receive(:run!).and_return(nil)
    allow(ReceiptService::Extract).to receive(:new).and_return(extract_service)
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

    it "bounces with the sender's address when it isn't on an HCB account" do
      sent_emails = capture_emails do
        receive_email(to: "receipts@hackclub.com", from: "unknown@example.com")
      end

      bounce = sent_emails.sole
      expect(bounce.to).to contain_exactly("unknown@example.com")
      expect(bounce.text_part.body.to_s).to include("We couldn't find an HCB account for unknown@example.com")
      expect(bounce.text_part.body.to_s).not_to include("This isn't a valid Receipt Bin inbox")
      expect(Receipt.count).to eq(0)
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

    it "bounces as an invalid inbox when the address isn't activated" do
      mailbox_address = create(:user).mailbox_addresses.create!

      sent_emails = capture_emails do
        receive_email(to: mailbox_address.address, from: "not-user@example.com")
      end

      bounce = sent_emails.sole
      expect(bounce.text_part.body.to_s).to include("This isn't a valid Receipt Bin inbox")
      expect(bounce.text_part.body.to_s).not_to include("not-user@example.com")
    end
  end
end
