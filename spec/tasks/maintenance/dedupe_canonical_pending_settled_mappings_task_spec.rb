# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::DedupeCanonicalPendingSettledMappingsTask do
  # This task exists to clean up rows that a pending migration will make
  # impossible to create (a unique index on canonical_pending_transaction_id).
  # If that index already exists in this database, drop it just for these
  # specs so we can construct the duplicated state the task cleans up; the
  # per-example transaction rolls the drop back afterwards.
  around do |example|
    index = ActiveRecord::Base.connection.indexes(:canonical_pending_settled_mappings)
                              .find { |i| i.unique && i.columns == ["canonical_pending_transaction_id"] }
    ActiveRecord::Base.connection.remove_index(:canonical_pending_settled_mappings, name: index.name) if index
    example.run
  end

  # Note: this task operates purely on existing canonical_pending_settled_mappings
  # rows (which the specs below wire up directly), not on stripe_authorization_id
  # matching, so these CTs are intentionally not linked to the CPT's authorization
  # id the way the real settle flow would.
  def stripe_canonical_transaction(stripe_card:, type: "capture")
    rst = create(:raw_stripe_transaction, stripe_card:)
    rst.stripe_transaction["type"] = type
    rst.save!

    create(:canonical_transaction,
           transaction_source: rst,
           hashed_transactions: [build(:hashed_transaction, :stripe, raw_stripe_transaction: rst)])
  end

  let(:stripe_card) { create(:stripe_card, :with_stripe_id) }
  let(:raw_pending_stripe_transaction) { create(:raw_pending_stripe_transaction, stripe_transaction_id: "iauth_1") }
  let(:canonical_pending_transaction) { create(:canonical_pending_transaction, raw_pending_stripe_transaction:) }

  context "when a CPT was settled to both the original charge and its refund" do
    let!(:capture_ct) { stripe_canonical_transaction(stripe_card:, type: "capture") }
    let!(:refund_ct) { stripe_canonical_transaction(stripe_card:, type: "refund") }

    before do
      create(:canonical_pending_settled_mapping, canonical_pending_transaction:, canonical_transaction: capture_ct)
      create(:canonical_pending_settled_mapping, canonical_pending_transaction:, canonical_transaction: refund_ct)
    end

    it "is included in the collection" do
      expect(described_class.new.collection).to include(canonical_pending_transaction)
    end

    it "keeps the mapping to the charge and destroys the mapping to the refund" do
      described_class.new.process(canonical_pending_transaction)

      expect(canonical_pending_transaction.reload.canonical_transactions).to eq([capture_ct])
    end
  end

  context "when a CPT is settled to a single CT" do
    let!(:capture_ct) { stripe_canonical_transaction(stripe_card:, type: "capture") }

    before do
      create(:canonical_pending_settled_mapping, canonical_pending_transaction:, canonical_transaction: capture_ct)
    end

    it "is not included in the collection" do
      expect(described_class.new.collection).to_not include(canonical_pending_transaction)
    end
  end

  context "when there's no non-refund candidate to keep" do
    let!(:refund_ct) { stripe_canonical_transaction(stripe_card:, type: "refund") }
    let!(:other_refund_ct) { stripe_canonical_transaction(stripe_card:, type: "refund") }

    before do
      create(:canonical_pending_settled_mapping, canonical_pending_transaction:, canonical_transaction: refund_ct)
      create(:canonical_pending_settled_mapping, canonical_pending_transaction:, canonical_transaction: other_refund_ct)
    end

    it "reports the anomaly and leaves the mappings untouched" do
      expect(Rails.error).to receive(:unexpected).with(instance_of(described_class::AnomalyError))

      expect {
        described_class.new.process(canonical_pending_transaction)
      }.to_not(change { canonical_pending_transaction.canonical_pending_settled_mappings.count })
    end
  end

  context "when there's more than one non-refund candidate" do
    let!(:capture_ct) { stripe_canonical_transaction(stripe_card:, type: "capture") }
    let(:other_canonical_transaction) { create(:canonical_transaction) }

    before do
      create(:canonical_pending_settled_mapping, canonical_pending_transaction:, canonical_transaction: capture_ct)
      create(:canonical_pending_settled_mapping, canonical_pending_transaction:, canonical_transaction: other_canonical_transaction)
    end

    it "reports the anomaly and leaves the mappings untouched" do
      expect(Rails.error).to receive(:unexpected).with(instance_of(described_class::AnomalyError))

      expect {
        described_class.new.process(canonical_pending_transaction)
      }.to_not(change { canonical_pending_transaction.canonical_pending_settled_mappings.count })
    end
  end
end
