# frozen_string_literal: true

require "rails_helper"

RSpec.describe Twilio::ProcessWebhookJob do
  # `phone_number_verified` is reset whenever `phone_number` changes, so set it separately.
  let(:user) { create(:user, phone_number: "+18556254225").tap { |u| u.update!(phone_number_verified: true) } }
  let(:phone_number) { user.phone_number } # stored in a normalized format
  let(:hcb_code) { create(:canonical_pending_transaction).local_hcb_code }
  let(:receipt_service) { instance_double(ReceiptService::Create, run!: [instance_double(Receipt, suggested_memo: nil)]) }
  let(:to_number) { "+15555550100" }
  let(:num_media) { "1" }
  let(:receipt_required) { true }

  let(:webhook_params) do
    {
      "From"              => phone_number,
      "To"                => to_number,
      "NumMedia"          => num_media,
      "MediaUrl0"         => "https://example.com/receipt.png",
      "MediaContentType0" => "image/png"
    }
  end

  before do
    freeze_time
    allow_any_instance_of(HcbCode).to receive(:receipt_required?).and_return(receipt_required)
    sent = TwilioMessage.create!(to: phone_number, from: "+15555550100", body: "Your card was charged", twilio_sid: "SM1", twilio_account_sid: "AC1")
    OutgoingTwilioMessage.create!(twilio_message: sent, hcb_code:, created_at: sent_at)

    stub_request(:get, "https://example.com/receipt.png").to_return(body: "image")
    allow(TwilioMessageService::Send).to receive(:new).and_return(instance_double(TwilioMessageService::Send, run!: true))
  end

  context "when the photo arrives within the reply window of the SMS" do
    let(:sent_at) { 8.minutes.ago }

    it "attaches the receipt to the charge" do
      expect(ReceiptService::Create).to receive(:new).with(hash_including(receiptable: hcb_code.ledger_item, upload_method: "sms")).and_return(receipt_service)

      described_class.perform_now(webhook_params:)
    end
  end

  context "when the photo arrives just inside the reply window" do
    let(:sent_at) { OutgoingTwilioMessage::RECEIPT_REPLY_WINDOW.ago + 1.second }

    it "attaches the receipt to the charge" do
      expect(ReceiptService::Create).to receive(:new).with(hash_including(receiptable: hcb_code.ledger_item)).and_return(receipt_service)

      described_class.perform_now(webhook_params:)
    end
  end

  context "when the photo arrives after the reply window" do
    let(:sent_at) { 11.minutes.ago }

    it "adds the receipt to the Receipt Bin" do
      expect(ReceiptService::Create).to receive(:new).with(hash_including(receiptable: nil, upload_method: "sms")).and_return(receipt_service)

      described_class.perform_now(webhook_params:)
    end
  end

  context "when the SMS was re-sent recently for an older charge" do
    let(:hcb_code) { create(:canonical_pending_transaction, created_at: 3.days.ago).local_hcb_code }
    let(:sent_at) { 5.minutes.ago }

    it "measures the window from the SMS, attaching the receipt to the charge" do
      expect(ReceiptService::Create).to receive(:new).with(hash_including(receiptable: hcb_code.ledger_item)).and_return(receipt_service)

      described_class.perform_now(webhook_params:)
    end
  end

  context "when the texted hcb code has no pending transaction" do
    let(:hcb_code) { create(:hcb_code) }
    let(:sent_at) { 5.minutes.ago }

    it "does not raise and still creates the receipt" do
      expect(ReceiptService::Create).to receive(:new).with(hash_including(receiptable: hcb_code.ledger_item)).and_return(receipt_service)

      expect { described_class.perform_now(webhook_params:) }.not_to raise_error
    end
  end

  context "when the last text was about a charge that needs no receipt, like a decline" do
    let(:receipt_required) { false }
    let(:sent_at) { 5.minutes.ago }

    it "adds the receipt to the Receipt Bin" do
      expect(ReceiptService::Create).to receive(:new).with(hash_including(receiptable: nil)).and_return(receipt_service)

      described_class.perform_now(webhook_params:)
    end
  end

  context "when two charges were texted within the reply window" do
    let(:sent_at) { 8.minutes.ago }
    let(:newer_hcb_code) { create(:canonical_pending_transaction).local_hcb_code }

    before do
      sent = TwilioMessage.create!(to: phone_number, from: "+15555550100", body: "Your card was charged", twilio_sid: "SM2", twilio_account_sid: "AC1")
      OutgoingTwilioMessage.create!(twilio_message: sent, hcb_code: newer_hcb_code, created_at: 3.minutes.ago)
    end

    it "attaches the receipt to the only one still missing a receipt" do
      allow_any_instance_of(HcbCode).to receive(:missing_receipt?) { |code| code == hcb_code }
      expect(ReceiptService::Create).to receive(:new).with(hash_including(receiptable: hcb_code.ledger_item)).and_return(receipt_service)

      described_class.perform_now(webhook_params:)
    end

    it "adds the receipt to the Receipt Bin when both are missing a receipt" do
      allow_any_instance_of(HcbCode).to receive(:missing_receipt?).and_return(true)
      expect(ReceiptService::Create).to receive(:new).with(hash_including(receiptable: nil)).and_return(receipt_service)

      described_class.perform_now(webhook_params:)
    end
  end

  context "when the photo is texted to the reimbursement number" do
    let(:to_number) { "+18023004260" }
    let(:sent_at) { 5.minutes.ago }

    it "attaches the receipt to a new reimbursement expense, not the texted charge" do
      expect(ReceiptService::Create).to receive(:new).with(hash_including(receiptable: an_instance_of(Reimbursement::Expense), upload_method: "sms_reimbursement")).and_return(receipt_service)

      described_class.perform_now(webhook_params:)
    end
  end

  context "when the number belongs to no verified user" do
    let(:phone_number) { "+15555550199" }
    let(:sent_at) { 5.minutes.ago }

    it "replies that the account wasn't found and creates no receipt" do
      expect(ReceiptService::Create).not_to receive(:new)
      expect(TwilioMessageService::Send).to receive(:new).with(nil, a_string_including("couldn't find your account"), phone_number:)

      described_class.perform_now(webhook_params:)
    end
  end

  context "when the message has no attachments" do
    let(:num_media) { "0" }
    let(:sent_at) { 5.minutes.ago }

    it "replies that no attachments were found and creates no receipt" do
      expect(ReceiptService::Create).not_to receive(:new)
      expect(TwilioMessageService::Send).to receive(:new).with(user, a_string_including("couldn't find any attachments"), phone_number:)

      described_class.perform_now(webhook_params:)
    end
  end
end
