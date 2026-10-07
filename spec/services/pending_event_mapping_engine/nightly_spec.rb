# frozen_string_literal: true

require "rails_helper"

RSpec.describe PendingEventMappingEngine::Nightly do
  describe "settling expense payouts" do
    let(:event) { create(:event) }
    let(:report) { create(:reimbursement_report, event:) }
    let(:expense) { create(:reimbursement_expense, report:, memo: "Wire fee", type: "Reimbursement::Expense::Fee") }

    let!(:payout) do
      expense.update_column(:aasm_state, "approved")
      report.update_column(:aasm_state, "reimbursement_approved")

      Reimbursement::ExpensePayout.create!(amount_cents: -expense.amount_cents, event:, expense:)
    end

    let!(:canonical_transaction) do
      create(:canonical_transaction, amount_cents: payout.amount_cents).tap do |ct|
        ct.update_column(:hcb_code, payout.hcb_code)
      end
    end

    it "copies the pending transaction's category to the settled transaction" do
      cpt = payout.canonical_pending_transaction
      expect(cpt.category.slug).to eq("bank-fees")

      described_class.new.send(:settle_canonical_pending_expense_payout!)

      expect(cpt.reload.canonical_transactions).to contain_exactly(canonical_transaction)
      expect(canonical_transaction.reload.category.slug).to eq("bank-fees")
      expect(canonical_transaction.category_mapping).to be_automatic
    end
  end

  describe "settling checks" do
    let(:event) { create(:event, :with_positive_balance) }

    let!(:check) do
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

    let!(:canonical_transaction) do
      create(:canonical_transaction, amount_cents: -10_00).tap do |ct|
        ct.update_column(:hcb_code, check.hcb_code)
      end
    end

    it "copies the pending transaction's category to the settled transaction" do
      cpt = check.canonical_pending_transaction
      TransactionCategoryService.new(model: cpt).set!(slug: "venue", assignment_strategy: "manual")

      described_class.new.send(:settle_canonical_pending_increase_check!)

      expect(cpt.reload.canonical_transactions).to contain_exactly(canonical_transaction)
      expect(canonical_transaction.reload.category.slug).to eq("venue")
      expect(canonical_transaction.category_mapping).to be_manual
    end
  end

  describe "settling wires" do
    before do
      stub_request(:get, /api\.column\.com\/institutions\/.*/)
        .to_return(status: 200, body: '{"country_code": "DE"}', headers: { "Content-Type" => "application/json" })
    end

    let(:event) { create(:event, :with_positive_balance) }
    let!(:wire) { create(:wire, :approved, event:, user: create(:user, :make_admin)) }

    let!(:canonical_transaction) do
      create(:canonical_transaction, amount_cents: wire.canonical_pending_transaction.amount_cents).tap do |ct|
        ct.update_column(:hcb_code, wire.hcb_code)
      end
    end

    it "copies the pending transaction's category to the settled transaction" do
      cpt = wire.canonical_pending_transaction
      TransactionCategoryService.new(model: cpt).set!(slug: "professional-fees-contractors", assignment_strategy: "manual")

      described_class.new.send(:settle_canonical_pending_wire!)

      expect(cpt.reload.canonical_transactions).to contain_exactly(canonical_transaction)
      expect(canonical_transaction.reload.category.slug).to eq("professional-fees-contractors")
      expect(canonical_transaction.category_mapping).to be_manual
      expect(wire.reload).to be_deposited
    end
  end

  describe "settling check deposits" do
    let(:event) { create(:event) }

    let!(:check_deposit) do
      CheckDeposit.create!(
        event:,
        created_by: create(:user),
        amount_cents: 25_00,
        front: { io: file_fixture("receipt.png").open, filename: "front.png", content_type: "image/png" },
        back: { io: file_fixture("receipt.png").open, filename: "back.png", content_type: "image/png" }
      )
    end

    let!(:canonical_transaction) do
      create(:canonical_transaction, amount_cents: 25_00).tap do |ct|
        ct.update_column(:hcb_code, check_deposit.hcb_code)
      end
    end

    it "copies the pending transaction's category to the settled transaction" do
      cpt = check_deposit.canonical_pending_transaction
      TransactionCategoryService.new(model: cpt).set!(slug: "fundraising", assignment_strategy: "manual")

      described_class.new.send(:settle_canonical_pending_check_deposit!)

      expect(cpt.reload.canonical_transactions).to contain_exactly(canonical_transaction)
      expect(canonical_transaction.reload.category.slug).to eq("fundraising")
      expect(canonical_transaction.category_mapping).to be_manual
    end
  end

  describe "settling payout holdings" do
    # Payout holdings live on the reimbursement clearinghouse event, which
    # must exist for the pending transaction to be created.
    let!(:clearinghouse) { create(:event, id: EventMappingEngine::EventIds::REIMBURSEMENT_CLEARING) }
    let(:report) { create(:reimbursement_report) }
    let!(:payout_holding) { Reimbursement::PayoutHolding.create!(report:, amount_cents: 10_00) }

    let!(:canonical_transaction) do
      create(:canonical_transaction, amount_cents: 10_00).tap do |ct|
        ct.update_column(:hcb_code, payout_holding.hcb_code)
      end
    end

    it "copies the pending transaction's category to the settled transaction" do
      cpt = payout_holding.canonical_pending_transaction
      TransactionCategoryService.new(model: cpt).set!(slug: "travel", assignment_strategy: "manual")

      described_class.new.send(:settle_canonical_pending_payout_holding!)

      expect(cpt.reload.canonical_transactions).to contain_exactly(canonical_transaction)
      expect(canonical_transaction.reload.category.slug).to eq("travel")
      expect(canonical_transaction.category_mapping).to be_manual
    end
  end

  describe "settling Stripe service fees" do
    # The pending transaction is mapped to the Hack Club Bank event, which must
    # exist for it to be created.
    let!(:hack_club_bank) { create(:event, id: EventMappingEngine::EventIds::HACK_CLUB_BANK) }

    before do
      # StripeServiceFee creates a StripeTopup on create, which calls the Stripe API.
      stub_request(:post, "https://api.stripe.com/v1/topups")
        .to_return(status: 200, body: { id: "tu_1" }.to_json, headers: {})
    end

    let(:stripe_service_fee) { create(:stripe_service_fee, amount_cents: -12_34) }
    let!(:cpt) { StripeServiceFeeService::CreateCanonicalPendingTransaction.new(stripe_service_fee_id: stripe_service_fee.id).run }

    let!(:canonical_transaction) do
      create(:canonical_transaction, amount_cents: cpt.amount_cents).tap do |ct|
        ct.update_column(:hcb_code, stripe_service_fee.hcb_code)
      end
    end

    it "copies the pending transaction's category to the settled transaction" do
      expect(cpt.category.slug).to eq("stripe-service-fees")

      described_class.new.send(:settle_canonical_pending_stripe_service_fee!)

      expect(cpt.reload.canonical_transactions).to contain_exactly(canonical_transaction)
      expect(canonical_transaction.reload.category.slug).to eq("stripe-service-fees")
      expect(canonical_transaction.category_mapping).to be_automatic
    end
  end
end
