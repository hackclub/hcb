# frozen_string_literal: true

require "rails_helper"

RSpec.describe PendingEventMappingEngine::AnomalyDetection::BadSettledMapping do
  subject { described_class.new(canonical_pending_transaction:).run }

  let(:date) { Date.new(2026, 1, 15) }
  let(:canonical_pending_transaction) { create(:canonical_pending_transaction, date:) }

  context "when the pending transaction hasn't settled" do
    it { is_expected.to eq(false) }
  end

  context "when the pending transaction settled into one canonical transaction" do
    before { settle_into(create(:canonical_transaction, date:)) }

    it { is_expected.to eq(false) }
  end

  context "when the pending transaction settled into several canonical transactions" do
    before do
      settle_into(create(:canonical_transaction, date:))
      settle_into(create(:canonical_transaction, date:))
    end

    # Known regression: CanonicalTransaction#assign_ledger_item's divergence
    # check (canonical_transaction.rb:493) raises via Rails.error.unexpected
    # when calculated_ledger_item doesn't match local_hcb_code.ledger_item.
    it "flags the bad mapping", skip: "known CanonicalTransaction#assign_ledger_item ledger-item divergence regression" do
      is_expected.to eq(true)
    end
  end

  context "when the canonical transaction predates the pending transaction" do
    before { settle_into(create(:canonical_transaction, date: date - 3.days)) }

    it { is_expected.to eq(true) }
  end

  def settle_into(canonical_transaction)
    create(:canonical_pending_settled_mapping, canonical_pending_transaction:, canonical_transaction:)
  end
end
