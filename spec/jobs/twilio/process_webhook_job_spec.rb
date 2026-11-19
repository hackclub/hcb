# frozen_string_literal: true

require "rails_helper"

RSpec.describe Twilio::ProcessWebhookJob do
  # `phone_number_verified` is reset whenever `phone_number` changes, so set it separately.
  let(:user) { create(:user, phone_number: "+18556254225").tap { |u| u.update!(phone_number_verified: true) } }
  let(:hcb_code) { create(:canonical_pending_transaction).local_hcb_code }
  let(:sent_at) { 5.minutes.ago }
  let(:webhook_params) { { "From" => user.phone_number, "To" => "+15555550100", "NumMedia" => "1", "MediaUrl0" => "https://example.com/receipt.png", "MediaContentType0" => "image/png" } }

  before do
    freeze_time
    allow_any_instance_of(HcbCode).to receive(:receipt_required?).and_return(true)
    text_about(hcb_code, at: sent_at)
    stub_request(:get, "https://example.com/receipt.png").to_return(body: "image")
    allow(TwilioMessageService::Send).to receive(:new).and_return(instance_double(TwilioMessageService::Send, run!: true))
  end

  def text_about(code, at:)
    sent = TwilioMessage.create!(to: user.phone_number, from: "+15555550100", body: "Your card was charged", twilio_sid: "SM#{code.id}", twilio_account_sid: "AC1")
    OutgoingTwilioMessage.create!(twilio_message: sent, hcb_code: code, created_at: at)
  end

  def expect_receipt_on(receiptable)
    receipt_service = instance_double(ReceiptService::Create, run!: [instance_double(Receipt, suggested_memo: nil)])
    expect(ReceiptService::Create).to receive(:new).with(hash_including(receiptable:, upload_method: "sms")).and_return(receipt_service)
    described_class.perform_now(webhook_params:)
  end

  context "just inside the reply window" do
    let(:sent_at) { OutgoingTwilioMessage::RECEIPT_REPLY_WINDOW.ago + 1.second }

    it("attaches to the charge") { expect_receipt_on(hcb_code.ledger_item) }
  end

  context "after the reply window" do
    let(:sent_at) { OutgoingTwilioMessage::RECEIPT_REPLY_WINDOW.ago - 1.second }

    it("goes to the Receipt Bin") { expect_receipt_on(nil) }
  end

  context "when the SMS was re-sent for an older charge" do
    let(:hcb_code) { create(:canonical_pending_transaction, created_at: 3.days.ago).local_hcb_code }

    it("measures the window from the SMS") { expect_receipt_on(hcb_code.ledger_item) }
  end

  context "when the hcb code has no pending transaction" do
    let(:hcb_code) { create(:hcb_code) }

    it("attaches to it without raising") { expect_receipt_on(hcb_code.ledger_item) }
  end

  it "sends a photo after a decline text to the Receipt Bin" do
    allow_any_instance_of(HcbCode).to receive(:receipt_required?).and_return(false)
    expect_receipt_on(nil)
  end

  context "when two charges were texted within the window" do
    before { text_about(create(:canonical_pending_transaction).local_hcb_code, at: 1.minute.ago) }

    it "attaches to the one still missing a receipt" do
      allow_any_instance_of(HcbCode).to receive(:missing_receipt?) { |code| code == hcb_code }
      expect_receipt_on(hcb_code.ledger_item)
    end

    it "goes to the Receipt Bin when both are missing one" do
      allow_any_instance_of(HcbCode).to receive(:missing_receipt?).and_return(true)
      expect_receipt_on(nil)
    end
  end
end
