# frozen_string_literal: true

require "rails_helper"

RSpec.describe DisbursementService::Nightly do
  describe "#run" do
    context "with no pending disbursements" do
      it "returns early without making API calls" do
        expect(ColumnService).not_to receive(:post)

        described_class.new.run
      end
    end

    context "with a single pending disbursement" do
      let!(:disbursement) { create(:disbursement, :pending, amount: 10000) }

      before do
        allow(ColumnService).to receive(:post)
      end

      it "creates two book transfers via ColumnService" do
        expect(ColumnService).to receive(:post).with(
          "/transfers/book",
          hash_including(
            idempotency_key: "#{disbursement.id}_outgoing",
            amount: 10000,
            currency_code: "USD",
            sender_bank_account_id: ColumnService::Accounts::FS_MAIN,
            receiver_bank_account_id: ColumnService::Accounts::FS_OPERATING
          )
        ).once

        expect(ColumnService).to receive(:post).with(
          "/transfers/book",
          hash_including(
            idempotency_key: "#{disbursement.id}_incoming",
            amount: 10000,
            currency_code: "USD",
            sender_bank_account_id: ColumnService::Accounts::FS_OPERATING,
            receiver_bank_account_id: ColumnService::Accounts::FS_MAIN
          )
        ).once

        described_class.new.run
      end

      it "uses the correct idempotency keys" do
        expect(ColumnService).to receive(:post).with(
          "/transfers/book",
          hash_including(idempotency_key: "#{disbursement.id}_outgoing")
        )
        expect(ColumnService).to receive(:post).with(
          "/transfers/book",
          hash_including(idempotency_key: "#{disbursement.id}_incoming")
        )

        described_class.new.run
      end

      it "uses the transaction memo in the description" do
        expect(ColumnService).to receive(:post).with(
          "/transfers/book",
          hash_including(description: disbursement.transaction_memo)
        ).twice

        described_class.new.run
      end

      it "marks the disbursement as in_transit" do
        described_class.new.run

        expect(disbursement.reload).to be_in_transit
      end
    end

    context "with multiple pending disbursements" do
      let!(:disbursement1) { create(:disbursement, :pending, amount: 5000) }
      let!(:disbursement2) { create(:disbursement, :pending, amount: 7500) }
      let!(:disbursement3) { create(:disbursement, :pending, amount: 2500) }

      before do
        allow(ColumnService).to receive(:post)
      end

      it "processes all pending disbursements" do
        expect(ColumnService).to receive(:post).exactly(6).times

        described_class.new.run

        expect(disbursement1.reload).to be_in_transit
        expect(disbursement2.reload).to be_in_transit
        expect(disbursement3.reload).to be_in_transit
      end
    end

    context "with non-pending disbursements" do
      let!(:reviewing_disbursement) { create(:disbursement) }
      let!(:in_transit_disbursement) { create(:disbursement, :in_transit) }
      let!(:deposited_disbursement) { create(:disbursement, :deposited) }

      it "does not process non-pending disbursements" do
        expect(ColumnService).not_to receive(:post)

        described_class.new.run
      end
    end

    context "with a mix of pending and non-pending disbursements" do
      let!(:pending_disbursement) { create(:disbursement, :pending, amount: 10000) }
      let!(:reviewing_disbursement) { create(:disbursement) }
      let!(:in_transit_disbursement) { create(:disbursement, :in_transit) }

      before do
        allow(ColumnService).to receive(:post)
      end

      it "only processes pending disbursements" do
        expect(ColumnService).to receive(:post).twice

        described_class.new.run

        expect(pending_disbursement.reload).to be_in_transit
        expect(reviewing_disbursement.reload).to be_reviewing
        expect(in_transit_disbursement.reload).to be_in_transit
      end
    end
  end
end
