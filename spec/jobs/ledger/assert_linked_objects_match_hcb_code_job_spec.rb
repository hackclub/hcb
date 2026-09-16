# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledger::AssertLinkedObjectsMatchHcbCodeJob do
  let(:bank_fee) { create(:bank_fee) }

  def anomalies
    reported = []
    job = described_class.new
    allow(job).to receive(:report_anomaly) { |message| reported << message }
    job.perform_now

    reported
  end

  def hcb_code_for(item, code)
    create(:hcb_code, hcb_code: code).tap { |hcb_code| hcb_code.update!(ledger_item: item) }
  end

  it "reports nothing when the linked objects agree" do
    item = create(:ledger_item, linked_object: bank_fee)
    hcb_code_for(item, "HCB-700-#{bank_fee.id}")

    expect(anomalies).to be_empty
  end

  it "reports an item linked to a different record of the same type" do
    item = create(:ledger_item, linked_object: bank_fee)
    hcb_code_for(item, "HCB-700-#{create(:bank_fee).id}")

    expect(anomalies).to contain_exactly(a_string_including("Ledger::Item #{item.hashid}"))
  end

  it "reports an item whose linked object type doesn't match the HCB code" do
    item = create(:ledger_item, linked_object: bank_fee)
    hcb_code_for(item, "HCB-100-#{bank_fee.id}")

    expect(anomalies).to contain_exactly(a_string_including("Ledger::Item #{item.hashid}"))
  end

  it "reports an item linked to an object the HCB code can't have" do
    item = create(:ledger_item, linked_object: create(:raw_pending_stripe_transaction).card_charge)
    hcb_code_for(item, "HCB-600-iauth_missing")

    expect(anomalies).to contain_exactly(a_string_including("Ledger::Item #{item.hashid}"))
  end

  it "ignores items with no linked object" do
    item = create(:ledger_item)
    hcb_code_for(item, "HCB-700-#{bank_fee.id}")

    expect(anomalies).to be_empty
  end

  it "ignores items with no HCB code" do
    create(:ledger_item, linked_object: bank_fee)

    expect(anomalies).to be_empty
  end
end
