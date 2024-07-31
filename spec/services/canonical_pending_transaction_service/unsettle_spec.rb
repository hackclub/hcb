# frozen_string_literal: true

require "rails_helper"

RSpec.describe CanonicalPendingTransactionService::Unsettle do
  let!(:canonical_transaction) { create(:canonical_transaction) }
  let(:canonical_pending_transaction) { create(:canonical_pending_transaction) }
  let(:event) { create(:event) }

  # Create enough balance to cover the ach_transfer amount.
  let!(:incoming_transaction) { create(:canonical_transaction, event:, amount_cents: 1000) }

  let(:service) {
    CanonicalPendingTransactionService::Unsettle.new( canonical_pending_transaction: )
  }

  it "deletes all associated canonical_pending_settled_mappings" do
    create_list(:canonical_pending_settled_mapping, 2,
                canonical_pending_transaction:,
                canonical_transaction: )


    service.run
    expect(CanonicalPendingSettledMapping.exists?).to eq(false)
  end

  it "marks ach_transfer in transit if it's deposited" do
    amount_cents = 500
    create(:canonical_pending_settled_mapping,
           canonical_pending_transaction:,
           canonical_transaction:)

    ach_transfer = create(:ach_transfer, event:, amount: amount_cents, aasm_state: "deposited", recipient_email: "sam@hackclub.com")
    create(:raw_pending_outgoing_ach_transaction, canonical_pending_transaction:, ach_transfer:, amount_cents:)

    expect(ach_transfer.in_transit?).to eq(false)

    service.run
    ach_transfer.reload

    expect(CanonicalPendingSettledMapping.exists?).to eq(false)
    expect(ach_transfer.in_transit?).to eq(true)
  end
end
