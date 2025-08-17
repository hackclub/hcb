# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReceiptBinMailbox do
  include ActionMailbox::TestHelper
  include ActionMailer::TestHelper

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
