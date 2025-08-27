# frozen_string_literal: true

require "rails_helper"

RSpec.describe EventMappingEngine::Map::HcbCodes::Short do
  it "maps canonical transactions to the appropriate event based on the short code" do
    # Create a mapped pending transaction which will also create an HCB code
    event = create(:event)
    cpt = create(:canonical_pending_transaction)
    cpt.create_canonical_pending_event_mapping!(event:)

    ct = create(:canonical_transaction, memo: "HCB-#{cpt.local_hcb_code.short_code}")
    # Sanity check to make sure this canonical transaction is eligible
    expect(CanonicalTransaction.unmapped.with_short_code).to include(ct)

    described_class.new.run

    ct.reload
    expect(ct.event).to eq(event)
    expect(ct.category).to be_nil
  end

  it "adds a category to bank fee transactions" do
    event = create(:event)
    bank_fee = create(:bank_fee, event:, amount_cents: -12_34)
    raw_pending_bank_fee_transaction = create(
      :raw_pending_bank_fee_transaction,
      amount_cents: bank_fee.amount_cents,
      bank_fee_transaction_id: bank_fee.id.to_s,
    )
    cpt = create(:canonical_pending_transaction, raw_pending_bank_fee_transaction:)
    cpt.create_canonical_pending_event_mapping!(event:)

    ct = create(:canonical_transaction, memo: "HCB-#{cpt.local_hcb_code.short_code}")

    described_class.new.run

    ct.reload
    expect(ct.event).to eq(event)
    expect(ct.category.slug).to eq("fiscal-sponsorship-fees")
    expect(ct.category_mapping.assignment_strategy).to eq("automatic")
  end

  it "adds a category to stripe fee transactions" do
    event = create(:event, id: EventMappingEngine::EventIds::HACK_CLUB_BANK)

    # `StripeServiceFee` creates a `StripeTopup` on creation, which results in a
    # call to the Stripe API
    stub_request(:post, "https://api.stripe.com/v1/topups")
      .to_return(status: 200, body: { id: "tu_1" }.to_json, headers: {})

    stripe_service_fee = StripeServiceFee.create!(
      amount_cents: 12_34,
      stripe_balance_transaction_id: "txn_1",
      stripe_description: "Test description"
    )
    local_hcb_code = stripe_service_fee.local_hcb_code

    ct = create(:canonical_transaction, memo: "HCB-#{local_hcb_code.short_code}")

    described_class.new.run

    ct.reload
    expect(ct.event).to eq(event)
    expect(ct.category.slug).to eq("stripe-service-fees")
    expect(ct.category_mapping.assignment_strategy).to eq("automatic")
  end

  it "adds a category to stripe fee reimbursements" do
    event = create(:event, id: EventMappingEngine::EventIds::HACK_CLUB_BANK)

    # Copied over from `FeeReimbursementService::Nightly`
    hcb_code = [
      TransactionGroupingEngine::Calculate::HcbCode::HCB_CODE,
      TransactionGroupingEngine::Calculate::HcbCode::OUTGOING_FEE_REIMBURSEMENT_CODE,
      Time.now.strftime("%G_%V")
    ].join(TransactionGroupingEngine::Calculate::HcbCode::SEPARATOR)

    local_hcb_code = HcbCode.create!(hcb_code: hcb_code)

    ct = create(:canonical_transaction, memo: "HCB-#{local_hcb_code.short_code}")

    described_class.new.run

    ct.reload
    expect(ct.event).to eq(event)
    expect(ct.category.slug).to eq("stripe-fee-reimbursements")
    expect(ct.category_mapping.assignment_strategy).to eq("automatic")
  end

  it "adds a category to fee revenue" do
    event = create(:event, id: EventMappingEngine::EventIds::HACK_CLUB_BANK)

    fee_revenue = FeeRevenue.create!(
      amount_cents: 12_34,
      start: Date.current.beginning_of_month,
      end: Date.current.end_of_month,
    )

    local_hcb_code = fee_revenue.local_hcb_code
    ct = create(:canonical_transaction, memo: "HCB-#{local_hcb_code.short_code}")

    described_class.new.run

    ct.reload
    expect(ct.event).to eq(event)
    expect(ct.category.slug).to eq("hcb-revenue")
    expect(ct.category_mapping.assignment_strategy).to eq("automatic")
  end

end
