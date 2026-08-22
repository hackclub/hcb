# frozen_string_literal: true

require "rails_helper"

RSpec.describe FeeReimbursementService::Nightly, type: :service do
  let!(:hack_club_bank) { Event.find_by(id: EventMappingEngine::EventIds::HACK_CLUB_BANK) || create(:event, id: EventMappingEngine::EventIds::HACK_CLUB_BANK) }

  describe "#run" do
    # Regression test for the backstop re-processing the same already-completed
    # reimbursements forever (it used to rely on `FeeReimbursement.pending`,
    # which keys off the dead pre-2021 `transactions` table and so never shrinks).
    describe "the backstop" do
      it "does not re-create a pending transaction for a reimbursement that already has one" do
        old = create(:fee_reimbursement, processed_at: 18.months.ago)
        rpfrt = old.create_raw_pending_fee_reimbursement_transaction!(date_posted: old.processed_at.to_date, amount_cents: -old.amount)
        CanonicalPendingTransaction.create!(date: rpfrt.date, amount_cents: rpfrt.amount_cents, memo: rpfrt.memo, raw_pending_fee_reimbursement_transaction: rpfrt)

        expect(FeeReimbursementService::CreateCanonicalPendingTransaction).not_to receive(:new)

        described_class.new.run
      end

      it "creates a pending transaction for an old, already-processed reimbursement that's still missing one" do
        old = create(:fee_reimbursement, processed_at: 18.months.ago)

        expect { described_class.new.run }.to change { old.reload.raw_pending_fee_reimbursement_transaction }.from(nil).to(be_present)
      end
    end

    # Regression test: a Stripe hiccup on one org's top-up used to raise out of
    # the whole method, unrescued, so the backstop below it never ran that night.
    describe "resilience to a per-record failure in the main loop" do
      it "reports the error, still processes other reimbursements, and still runs the backstop" do
        boom = create(:fee_reimbursement, amount: 12_34)
        fine = create(:fee_reimbursement, amount: 12_34)
        old = create(:fee_reimbursement, processed_at: 18.months.ago)

        allow(StripeTopup).to receive(:create) do |amount_cents:, statement_descriptor:, description:, metadata:|
          raise Stripe::APIConnectionError, "boom" if metadata[:fee_reimbursement_id] == boom.id

          instance_double(StripeTopup, id: 999)
        end

        expect(Rails.error).to receive(:report).with(instance_of(Stripe::APIConnectionError))

        expect { described_class.new.run }.not_to raise_error

        expect(boom.reload.processed_at).to be_nil
        expect(fine.reload.processed_at).to be_present
        expect(old.reload.raw_pending_fee_reimbursement_transaction).to be_present
      end
    end
  end
end
