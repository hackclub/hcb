# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledger::AssertCptsSyncedWithHcbCodeJob do
  let(:item) { create(:ledger_item) }
  let(:hcb_code) { create(:hcb_code).tap { |code| code.update!(ledger_item: item) } }

  def anomalies
    reported = []
    job = described_class.new
    allow(job).to receive(:report_anomaly) { |message| reported << message }
    job.perform_now

    reported
  end

  # The ledger item a transaction lands on is assigned by callbacks, so set the
  # column directly to build the states this job exists to catch.
  def canonical_pending_transaction(hcb_code:, ledger_item:)
    create(:canonical_pending_transaction).tap do |cpt|
      cpt.update_columns(hcb_code:, ledger_item_id: ledger_item&.id)
    end
  end

  it "reports nothing when a transaction and its HCB code agree" do
    canonical_pending_transaction(hcb_code: hcb_code.hcb_code, ledger_item: item)

    expect(anomalies).to be_empty
  end

  it "reports nothing when neither has a ledger item" do
    hcb_code.update!(ledger_item: nil)
    canonical_pending_transaction(hcb_code: hcb_code.hcb_code, ledger_item: nil)

    expect(anomalies).to be_empty
  end

  it "reports a transaction on a different ledger item than its HCB code" do
    cpt = canonical_pending_transaction(hcb_code: hcb_code.hcb_code, ledger_item: create(:ledger_item))

    expect(anomalies).to contain_exactly(a_string_including("CanonicalPendingTransaction #{cpt.id}"))
  end

  it "reports a transaction with no ledger item whose HCB code has one" do
    cpt = canonical_pending_transaction(hcb_code: hcb_code.hcb_code, ledger_item: nil)

    expect(anomalies).to contain_exactly(a_string_including("CanonicalPendingTransaction #{cpt.id}"))
  end

  it "reports a transaction on a ledger item whose HCB code doesn't exist" do
    cpt = canonical_pending_transaction(hcb_code: "HCB-000-missing", ledger_item: item)

    expect(anomalies).to contain_exactly(a_string_including("CanonicalPendingTransaction #{cpt.id}"))
  end
end
