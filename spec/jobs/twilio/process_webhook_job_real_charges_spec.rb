# frozen_string_literal: true

require "rails_helper"

# Unlike process_webhook_job_spec.rb, nothing here stubs `receipt_required?` or
# `missing_receipt?`: these are real card charges, a real decline, and a real receipt.
RSpec.describe Twilio::ProcessWebhookJob do
  let(:user) { create(:user, phone_number: "+18556254225").tap { |u| u.update!(phone_number_verified: true) } }
  let(:event) { create(:event) }
  let(:receipt_service) { instance_double(ReceiptService::Create, run!: [instance_double(Receipt, suggested_memo: nil)]) }
  let(:webhook_params) do
    {
      "From"              => user.phone_number,
      "To"                => "+15555550100",
      "NumMedia"          => "1",
      "MediaUrl0"         => "https://example.com/receipt.png",
      "MediaContentType0" => "image/png"
    }
  end

  before do
    freeze_time
    stub_request(:get, "https://example.com/receipt.png").to_return(body: "image")
    allow(TwilioMessageService::Send).to receive(:new).and_return(instance_double(TwilioMessageService::Send, run!: true))
  end

  def card_charge
    rpst = create(:raw_pending_stripe_transaction, amount_cents: -1000)
    create(:canonical_pending_transaction, raw_pending_stripe_transaction: rpst, event:, amount_cents: -1000).local_hcb_code
  end

  def text_about(hcb_code, at:)
    sent = TwilioMessage.create!(to: user.phone_number, from: "+15555550100", body: "Your card was charged", twilio_sid: "SM#{hcb_code.id}", twilio_account_sid: "AC1")
    OutgoingTwilioMessage.create!(twilio_message: sent, hcb_code:, created_at: at)
  end

  it "attaches the photo to the charge texted earlier, not a decline texted after it" do
    charge = card_charge
    decline = card_charge
    CanonicalPendingDeclinedMapping.create!(canonical_pending_transaction: decline.pt)
    expect([charge.receipt_required?, decline.reload.receipt_required?]).to eq([true, false])

    text_about(charge, at: 8.minutes.ago)
    text_about(decline, at: 3.minutes.ago)

    expect(ReceiptService::Create).to receive(:new).with(hash_including(receiptable: charge.ledger_item)).and_return(receipt_service)
    described_class.perform_now(webhook_params:)
  end

  it "attaches the photo to the one of two texted charges that has no receipt yet" do
    first = card_charge
    second = card_charge
    text_about(first, at: 8.minutes.ago)
    ReceiptService::Create.new(receiptable: first.ledger_item, uploader: user, attachments: [file_fixture("receipt.png")], upload_method: "sms").run!
    text_about(second, at: 3.minutes.ago)
    expect([first.reload.missing_receipt?, second.missing_receipt?]).to eq([false, true])

    expect(ReceiptService::Create).to receive(:new).with(hash_including(receiptable: second.ledger_item)).and_return(receipt_service)
    described_class.perform_now(webhook_params:)
  end
end
