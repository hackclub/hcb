# frozen_string_literal: true

require "rails_helper"

RSpec.describe Twilio::ProcessWebhookJob do
  # `phone_number_verified` is reset whenever `phone_number` changes, so set it separately.
  let(:user) { create(:user, phone_number: "+18556254225").tap { |u| u.update!(phone_number_verified: true) } }
  let(:phone_number) { user.phone_number } # stored in a normalized format
  let(:hcb_code) { create(:canonical_pending_transaction).local_hcb_code }
  let(:receipt_service) { instance_double(ReceiptService::Create, run!: [instance_double(Receipt)]) }

  let(:webhook_params) do
    {
      "From"              => phone_number,
      "To"                => "+15555550100",
      "NumMedia"          => "1",
      "MediaUrl0"         => "https://example.com/receipt.png",
      "MediaContentType0" => "image/png"
    }
  end

  before do
    sent = TwilioMessage.create!(to: phone_number, from: "+15555550100", body: "Your card was charged", twilio_sid: "SM1", twilio_account_sid: "AC1")
    OutgoingTwilioMessage.create!(twilio_message: sent, hcb_code:, created_at: sent_at)

    stub_request(:get, "https://example.com/receipt.png").to_return(body: "image")
    allow(TwilioMessageService::Send).to receive(:new).and_return(instance_double(TwilioMessageService::Send, run!: true))
  end

  context "when the photo arrives within the reply window of the SMS" do
    let(:sent_at) { 50.minutes.ago }

    it "attaches the receipt to the charge" do
      expect(ReceiptService::Create).to receive(:new).with(hash_including(receiptable: hcb_code.ledger_item)).and_return(receipt_service)

      described_class.perform_now(webhook_params:)
    end
  end

  context "when the photo arrives after the reply window" do
    let(:sent_at) { 61.minutes.ago }

    it "adds the receipt to the Receipt Bin" do
      expect(ReceiptService::Create).to receive(:new).with(hash_including(receiptable: nil)).and_return(receipt_service)

      described_class.perform_now(webhook_params:)
    end
  end
end
