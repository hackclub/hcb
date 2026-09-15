# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledger::AssertEmptyItemsHaveZeroAmountJob do
  def anomalies
    reported = []
    job = described_class.new
    allow(job).to receive(:report_anomaly) { |message| reported << message }
    job.perform_now

    reported
  end

  it "reports an item with no transactions and a non-zero amount" do
    item = create(:ledger_item, amount_cents: 1000)
    item.update_columns(ct_count: 0, cpt_count: 0, amount_cents: 1000)

    expect(anomalies).to contain_exactly(a_string_including("Ledger::Item #{item.hashid}"))
  end

  it "ignores an item with no transactions and no amount" do
    create(:ledger_item, amount_cents: 0)

    expect(anomalies).to be_empty
  end

  it "ignores an item that has transactions" do
    item = create(:ledger_item, amount_cents: 1000)
    item.update_columns(ct_count: 1, amount_cents: 1000)

    expect(anomalies).to be_empty
  end
end
