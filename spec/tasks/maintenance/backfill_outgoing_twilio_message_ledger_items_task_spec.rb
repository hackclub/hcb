# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::BackfillOutgoingTwilioMessageLedgerItemsTask do
  def text_about(hcb_code, ledger_item: nil)
    sent = TwilioMessage.create!(to: "+18556254225", from: "+15555550100", body: "Your card was charged", twilio_sid: "SM#{SecureRandom.hex(4)}", twilio_account_sid: "AC1")
    OutgoingTwilioMessage.create!(twilio_message: sent, hcb_code:, ledger_item:)
  end

  it "points messages at their HCB code's ledger item" do
    hcb_code = create(:canonical_pending_transaction).local_hcb_code
    legacy = text_about(hcb_code)
    already_filled = text_about(hcb_code, ledger_item: hcb_code.ledger_item)
    without_item = text_about(create(:hcb_code))
    not_about_a_transaction = text_about(nil)

    expect(described_class.collection.map(&:to_a).flatten).to contain_exactly(legacy)

    described_class.collection.each { |batch| described_class.process(batch) }

    expect(legacy.reload.ledger_item).to eq(hcb_code.ledger_item)
    expect(already_filled.reload.ledger_item).to eq(hcb_code.ledger_item)
    expect(without_item.reload.ledger_item).to be_nil
    expect(not_about_a_transaction.reload.ledger_item).to be_nil
    expect(described_class.collection.map(&:to_a).flatten).to be_empty
  end
end
