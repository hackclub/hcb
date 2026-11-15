# frozen_string_literal: true

require "rails_helper"

RSpec.describe PendingEventMappingEngine::Settle::Single::HcbCode do
  let(:event) { create(:event, :with_positive_balance) }

  let(:check) do
    IncreaseCheck.create!(
      event:,
      amount: 10_00,
      memo: "Venue deposit",
      payment_for: "Venue deposit",
      recipient_name: "Recipient",
      recipient_email: "recipient@example.com",
      address_line1: "1 Main St",
      address_city: "City",
      address_state: "CA",
      address_zip: "94000"
    )
  end
  let(:cpt) { check.canonical_pending_transaction }

  # Returns a fresh instance so the spec's update_column doesn't leave a stale
  # local_hcb_code association behind.
  def canonical_transaction_with(hcb_code, amount_cents:)
    ct = create(:canonical_transaction, amount_cents:)
    ct.update_column(:hcb_code, hcb_code)
    CanonicalTransaction.find(ct.id)
  end

  it "settles the unsettled pending transaction sharing the HCB code" do
    ct = canonical_transaction_with(check.hcb_code, amount_cents: -10_00)

    expect(described_class.new(canonical_transaction: ct).run).to eq(cpt)

    expect(cpt.reload.canonical_transactions).to contain_exactly(ct)
    expect(ct.reload.canonical_pending_transaction).to eq(cpt)
  end

  it "does nothing when the pending transaction is already settled" do
    settled = canonical_transaction_with(check.hcb_code, amount_cents: -10_00)
    CanonicalPendingTransactionService::Settle.new(canonical_transaction: settled, canonical_pending_transaction: cpt).run!

    ct = canonical_transaction_with(check.hcb_code, amount_cents: -10_00)

    expect { described_class.new(canonical_transaction: ct).run }.not_to change(CanonicalPendingSettledMapping, :count)
  end

  it "does nothing when there is no pending transaction for the HCB code" do
    ct = canonical_transaction_with("HCB-401-999999", amount_cents: -10_00)

    expect { described_class.new(canonical_transaction: ct).run }.not_to change(CanonicalPendingSettledMapping, :count)
  end

  it "ignores unknown (HCB-000) codes, which are not unique between CTs and CPTs" do
    cpt = create(:canonical_pending_transaction)
    cpt.update_column(:hcb_code, "HCB-000-#{cpt.id}")
    HcbCode.find_or_create_by!(hcb_code: cpt.hcb_code)
    ct = canonical_transaction_with(cpt.hcb_code, amount_cents: cpt.amount_cents)

    expect { described_class.new(canonical_transaction: ct).run }.not_to change(CanonicalPendingSettledMapping, :count)
  end

  context "with a wire" do
    before do
      stub_request(:get, /api\.column\.com\/institutions\/.*/)
        .to_return(status: 200, body: '{"country_code": "DE"}', headers: { "Content-Type" => "application/json" })
    end

    let!(:wire) { create(:wire, :approved, event:, user: create(:user, :make_admin)) }

    it "marks the wire deposited like the nightly settler does" do
      ct = canonical_transaction_with(wire.hcb_code, amount_cents: wire.canonical_pending_transaction.amount_cents)

      described_class.new(canonical_transaction: ct).run

      expect(wire.canonical_pending_transaction.reload.canonical_transactions).to contain_exactly(ct)
      expect(wire.reload).to be_deposited
    end
  end

  context "with a disbursement" do
    let(:disbursement) { create(:disbursement, :pending, source_event: event, amount: 25_00) }
    let!(:outgoing_cpt) do
      raw = create(:raw_pending_outgoing_disbursement_transaction, disbursement:, amount_cents: -25_00)
      create(:canonical_pending_transaction, raw_pending_outgoing_disbursement_transaction: raw, event:, amount_cents: -25_00)
    end

    it "matches on amount like the disbursement settlers do" do
      expect(outgoing_cpt.hcb_code).to start_with("HCB-500-")

      wrong_amount = canonical_transaction_with(outgoing_cpt.hcb_code, amount_cents: 25_00)
      expect { described_class.new(canonical_transaction: wrong_amount).run }.not_to change(CanonicalPendingSettledMapping, :count)

      right_amount = canonical_transaction_with(outgoing_cpt.hcb_code, amount_cents: -25_00)
      expect(described_class.new(canonical_transaction: right_amount).run).to eq(outgoing_cpt)
    end
  end
end
