# frozen_string_literal: true

require "rails_helper"

RSpec.describe CanonicalPendingTransaction, type: :model do
  let(:canonical_pending_transaction) { create(:canonical_pending_transaction) }

  it "is valid" do
    expect(canonical_pending_transaction).to be_valid
  end

  describe "hcb_code" do
    let(:canonical_pending_transaction) {
      create(:canonical_pending_transaction)
    }
    let(:hcb_code) { canonical_pending_transaction.reload.hcb_code }

    it "calculates it on create" do
      expect(hcb_code).to eql("HCB-000-#{canonical_pending_transaction.id}")
    end

    context "when a raw_pending_stripe_transaction is attached" do
      let(:raw_pending_stripe_transaction) { create(:raw_pending_stripe_transaction) }

      let(:canonical_pending_transaction) {
        create(:canonical_pending_transaction,
               raw_pending_stripe_transaction:)
      }

      it "returns it" do
        rpst = canonical_pending_transaction.raw_pending_stripe_transaction

        expect(rpst).to eql(raw_pending_stripe_transaction)
      end

      it "calculates a different hcb code" do
        expect(hcb_code).to eql("HCB-600-#{raw_pending_stripe_transaction.stripe_transaction_id}")
      end
    end
  end

  describe "#event" do
    let(:event) { create(:event) }
    let(:canonical_pending_transaction) { create(:canonical_pending_transaction) }

    before do
      CanonicalPendingEventMapping.create!(event:, canonical_pending_transaction:)
    end

    it "returns event" do
      expect(canonical_pending_transaction.event).to be_present
      expect(canonical_pending_transaction.event).to eq(event)
    end
  end

  describe "#stripe_card" do
    let!(:raw_pending_stripe_transaction) { create(:raw_pending_stripe_transaction) }
    let!(:canonical_pending_transaction) { create(:canonical_pending_transaction, raw_pending_stripe_transaction:) }
    let!(:stripe_card) { create(:stripe_card, :with_stripe_id, stripe_id: raw_pending_stripe_transaction.stripe_transaction["card"]["id"]) }

    it "returns stripe card" do
      sc = canonical_pending_transaction.stripe_card

      expect(sc).to eql(stripe_card)
    end
  end

  describe "ledger_item auto-creation" do
    it "creates a ledger_item on create when none is provided" do
      cpt = create(:canonical_pending_transaction, amount_cents: -999)

      expect(cpt.ledger_item).to be_present
      expect(cpt.ledger_item.amount_cents).to eq(cpt.amount_cents)
    end

    it "does not create a ledger_item when one is already provided" do
      existing_item = Ledger::Item.new(memo: "Existing", amount_cents: 500, datetime: Time.current)
      existing_item.save(validate: false)

      cpt = create(:canonical_pending_transaction, ledger_item: existing_item)

      expect(cpt.ledger_item).to eq(existing_item)
      expect(Ledger::Item.count).to eq(1)
    end
  end

  describe "stripe service fee" do
    let!(:hack_club_bank) { create(:event, id: EventMappingEngine::EventIds::HACK_CLUB_BANK) }

    before do
      stub_request(:post, "https://api.stripe.com/v1/topups")
        .to_return(status: 200, body: { id: "tu_1" }.to_json, headers: {})
    end

    let(:stripe_service_fee) { create(:stripe_service_fee) }
    let(:canonical_pending_transaction) do
      StripeServiceFeeService::CreateCanonicalPendingTransaction.new(stripe_service_fee_id: stripe_service_fee.id).run
    end

    it "is reachable through the raw_pending_stripe_service_fee_transaction association" do
      expect(canonical_pending_transaction.raw_pending_stripe_service_fee_transaction)
        .to eq(stripe_service_fee.raw_pending_stripe_service_fee_transaction)
    end

    it "is returned by the .stripe_service_fee scope" do
      expect(CanonicalPendingTransaction.stripe_service_fee).to include(canonical_pending_transaction)
    end

    it "excludes transactions with no raw pending stripe service fee transaction from the scope" do
      unrelated = create(:canonical_pending_transaction)

      expect(CanonicalPendingTransaction.stripe_service_fee).not_to include(unrelated)
    end
  end

  describe "fee revenue" do
    let!(:hack_club_bank) { create(:event, id: EventMappingEngine::EventIds::HACK_CLUB_BANK) }
    let(:fee_revenue) { create(:fee_revenue) }
    let(:canonical_pending_transaction) do
      FeeRevenueService::CreateCanonicalPendingTransaction.new(fee_revenue_id: fee_revenue.id).run
    end

    it "is reachable through the raw_pending_fee_revenue_transaction association" do
      expect(canonical_pending_transaction.raw_pending_fee_revenue_transaction)
        .to eq(fee_revenue.raw_pending_fee_revenue_transaction)
    end

    it "is returned by the .fee_revenue scope" do
      expect(CanonicalPendingTransaction.fee_revenue).to include(canonical_pending_transaction)
    end

    it "excludes transactions with no raw pending fee revenue transaction from the scope" do
      unrelated = create(:canonical_pending_transaction)

      expect(CanonicalPendingTransaction.fee_revenue).not_to include(unrelated)
    end
  end

  describe "fee reimbursement" do
    let!(:hack_club_bank) { create(:event, id: EventMappingEngine::EventIds::HACK_CLUB_BANK) }
    let(:fee_reimbursement) { create(:fee_reimbursement, amount: 12_34) }
    let(:canonical_pending_transaction) do
      FeeReimbursementService::CreateCanonicalPendingTransaction.new(fee_reimbursement_id: fee_reimbursement.id).run
    end

    it "is reachable through the raw_pending_fee_reimbursement_transaction association" do
      expect(canonical_pending_transaction.raw_pending_fee_reimbursement_transaction)
        .to eq(fee_reimbursement.raw_pending_fee_reimbursement_transaction)
    end

    it "is returned by the .fee_reimbursement scope" do
      expect(CanonicalPendingTransaction.fee_reimbursement).to include(canonical_pending_transaction)
    end

    it "excludes transactions with no raw pending fee reimbursement transaction from the scope" do
      unrelated = create(:canonical_pending_transaction)

      expect(CanonicalPendingTransaction.fee_reimbursement).not_to include(unrelated)
    end
  end

  describe "#search_memo" do
    context "when the memo is a partial match for the search query" do
      it "still finds the transaction" do
        canonical_pending_transaction = create(:canonical_pending_transaction, memo: "POSTAGE GOSHIPPO.COM")
        expect(CanonicalPendingTransaction.search_memo("go shippo")).to contain_exactly(canonical_pending_transaction)
      end
    end
  end
end
