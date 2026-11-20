# frozen_string_literal: true

require "rails_helper"

RSpec.describe Twilio::ProcessWebhookJob do
  # `phone_number_verified` is reset whenever `phone_number` changes, so set it separately.
  let(:user) { create(:user, phone_number: "+18556254225").tap { |u| u.update!(phone_number_verified: true) } }
  let(:ledger_item) { charge_item }
  let(:sent_at) { 5.minutes.ago }
  let(:webhook_params) { { "From" => user.phone_number, "To" => "+15555550100", "NumMedia" => "1", "MediaUrl0" => "https://example.com/receipt.png", "MediaContentType0" => "image/png" } }

  before do
    freeze_time
    text_about(ledger_item, at: sent_at)
    stub_request(:get, "https://example.com/receipt.png").to_return(body: "image")
    allow(TwilioMessageService::Send).to receive(:new).and_return(instance_double(TwilioMessageService::Send, run!: true))
  end

  # A card charge's ledger item, which asks for a receipt. `receipt_required`
  # is a cached column recalculated from the primary ledger, so set it directly.
  def charge_item(**attributes)
    create(:canonical_pending_transaction, **attributes).ledger_item.tap { |item| item.update_columns(receipt_required: true) }
  end

  def text_about(item, at:)
    sent = TwilioMessage.create!(to: user.phone_number, from: "+15555550100", body: "Your card was charged", twilio_sid: "SM#{item.id}", twilio_account_sid: "AC1")
    OutgoingTwilioMessage.create!(twilio_message: sent, ledger_item: item, created_at: at)
  end

  def expect_receipt_on(receiptable, uploader: anything)
    receipt_service = instance_double(ReceiptService::Create, run!: [instance_double(Receipt, suggested_memo: nil)])
    expect(ReceiptService::Create).to receive(:new).with(hash_including(receiptable:, uploader:, upload_method: "sms")).and_return(receipt_service)
    described_class.perform_now(webhook_params:)
  end

  context "just inside the reply window" do
    let(:sent_at) { OutgoingTwilioMessage::RECEIPT_REPLY_WINDOW.ago + 1.second }

    it "attaches to the charge and links to it" do
      expect_receipt_on(ledger_item)

      expect(TwilioMessageService::Send).to have_received(:new).with(user, "Attached 1 receipt to #{ledger_item.memo}! #{Rails.application.routes.url_helpers.ledger_item_url(ledger_item)}", phone_number: user.phone_number)
    end
  end

  context "after the reply window" do
    let(:sent_at) { OutgoingTwilioMessage::RECEIPT_REPLY_WINDOW.ago - 1.second }

    it("goes to the Receipt Bin") { expect_receipt_on(nil) }
  end

  context "when the SMS was re-sent for an older charge" do
    let(:ledger_item) { charge_item(created_at: 3.days.ago) }

    it("measures the window from the SMS") { expect_receipt_on(ledger_item) }
  end

  it "sends a photo after a decline text to the Receipt Bin" do
    ledger_item.update_columns(receipt_required: false)
    expect_receipt_on(nil)
  end

  context "when two charges were texted within the window" do
    let(:other_item) { charge_item }

    before { text_about(other_item, at: 1.minute.ago) }

    it "attaches to the one still missing a receipt" do
      other_item.update_columns(receipt_count: 1)
      expect_receipt_on(ledger_item)
    end

    it "goes to the Receipt Bin when both are missing one" do
      expect_receipt_on(nil)
    end
  end

  context "when several users share the number" do
    let(:other_user) { create(:user, phone_number: user.phone_number).tap { |u| u.update!(phone_number_verified: true) } }
    let(:ledger_item) do
      stripe_card = create(:stripe_card, :with_stripe_id, stripe_cardholder: create(:stripe_cardholder, user:))
      raw_pending_stripe_transaction = create(:raw_pending_stripe_transaction, stripe_card:)
      charge_item(raw_pending_stripe_transaction:)
    end

    it "picks the one whose card we texted about" do
      other_user
      expect_receipt_on(ledger_item, uploader: user)
    end
  end
end
