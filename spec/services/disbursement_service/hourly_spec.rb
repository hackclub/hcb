# frozen_string_literal: true

require "rails_helper"

RSpec.describe DisbursementService::Hourly do
  # Helper to create a canonical transaction with a specific hcb_code
  # bypassing the after_create callback that would overwrite it
  def create_ct_with_hcb_code(hcb_code:, amount_cents:)
    ct = create(:canonical_transaction, amount_cents: amount_cents)
    ct.update_column(:hcb_code, hcb_code)
    ct
  end

  describe "#run" do
    context "with no in_transit disbursements" do
      let!(:reviewing_disbursement) { create(:disbursement) }
      let!(:pending_disbursement) { create(:disbursement, :pending) }
      let!(:deposited_disbursement) { create(:disbursement, :deposited) }

      it "does nothing" do
        described_class.new.run

        expect(reviewing_disbursement.reload).to be_reviewing
        expect(pending_disbursement.reload).to be_pending
        expect(deposited_disbursement.reload).to be_deposited
      end
    end

    context "with in_transit disbursement with 0 canonical transactions" do
      let!(:disbursement) { create(:disbursement, :in_transit) }

      it "keeps the disbursement in_transit" do
        described_class.new.run

        expect(disbursement.reload).to be_in_transit
      end
    end

    context "with in_transit disbursement with 1 canonical transaction" do
      let!(:disbursement) { create(:disbursement, :in_transit) }

      before do
        create_ct_with_hcb_code(hcb_code: disbursement.hcb_code, amount_cents: -disbursement.amount)
        # Clear memoization on the disbursement
        disbursement.instance_variable_set(:@canonical_transactions, nil)
      end

      it "keeps the disbursement in_transit" do
        described_class.new.run

        expect(disbursement.reload).to be_in_transit
      end
    end

    context "with in_transit disbursement with 2 canonical transactions" do
      let!(:disbursement) { create(:disbursement, :in_transit) }

      before do
        create_ct_with_hcb_code(hcb_code: disbursement.hcb_code, amount_cents: -disbursement.amount)
        create_ct_with_hcb_code(hcb_code: disbursement.hcb_code, amount_cents: disbursement.amount)
        # Clear memoization on the disbursement
        disbursement.instance_variable_set(:@canonical_transactions, nil)
      end

      it "marks the disbursement as deposited" do
        described_class.new.run

        expect(disbursement.reload).to be_deposited
      end
    end

    context "with in_transit disbursement with more than 2 canonical transactions" do
      let!(:disbursement) { create(:disbursement, :in_transit) }

      before do
        create_ct_with_hcb_code(hcb_code: disbursement.hcb_code, amount_cents: -disbursement.amount)
        create_ct_with_hcb_code(hcb_code: disbursement.hcb_code, amount_cents: disbursement.amount)
        create_ct_with_hcb_code(hcb_code: disbursement.hcb_code, amount_cents: 100)
        # Clear memoization on the disbursement
        disbursement.instance_variable_set(:@canonical_transactions, nil)
      end

      it "logs an error" do
        expect(Rails.error).to receive(:unexpected).with("Disbursement #{disbursement.id} has more than 2 canonical transactions!")

        described_class.new.run
      end

      it "does not mark the disbursement as deposited" do
        allow(Rails.error).to receive(:unexpected)

        described_class.new.run

        expect(disbursement.reload).to be_in_transit
      end
    end

    context "with multiple in_transit disbursements" do
      let!(:disbursement1) { create(:disbursement, :in_transit) }
      let!(:disbursement2) { create(:disbursement, :in_transit) }
      let!(:disbursement3) { create(:disbursement, :in_transit) }

      before do
        # disbursement1: 2 CTs - should be deposited
        create_ct_with_hcb_code(hcb_code: disbursement1.hcb_code, amount_cents: -disbursement1.amount)
        create_ct_with_hcb_code(hcb_code: disbursement1.hcb_code, amount_cents: disbursement1.amount)

        # disbursement2: 1 CT - should stay in_transit
        create_ct_with_hcb_code(hcb_code: disbursement2.hcb_code, amount_cents: -disbursement2.amount)

        # disbursement3: 0 CTs - should stay in_transit
      end

      it "processes each disbursement correctly" do
        described_class.new.run

        expect(disbursement1.reload).to be_deposited
        expect(disbursement2.reload).to be_in_transit
        expect(disbursement3.reload).to be_in_transit
      end
    end
  end
end
