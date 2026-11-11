# frozen_string_literal: true

require "rails_helper"

RSpec.describe CheckDeposit, type: :model do
  describe "#update_from_column_status!" do
    let(:check_deposit) { create(:check_deposit, :submitted) }

    it "rejects the deposit when Column rejects it" do
      expect {
        check_deposit.update_from_column_status!("rejected")
      }.to have_enqueued_mail(CheckDepositMailer, :rejected)

      expect(check_deposit.reload).to be_rejected
      expect(check_deposit.rejection_reason).to eq("unknown")
      expect(check_deposit.canonical_pending_transaction).to be_declined
    end

    it "marks the deposit deposited once Column settles it" do
      check_deposit.update_from_column_status!("settled")

      expect(check_deposit.reload).to be_deposited
    end

    it "marks the deposit returned when Column returns it" do
      check_deposit.update_from_column_status!("returned")

      expect(check_deposit.reload).to be_returned
    end

    # Column's `deposited` means the check was sent to the Fed, not that the
    # money has arrived.
    %w[initiated manual_review pending_deposit deposited pending_reclear recleared].each do |column_status|
      it "leaves the deposit submitted while Column's status is #{column_status}" do
        expect {
          check_deposit.update_from_column_status!(column_status)
        }.not_to have_enqueued_mail(CheckDepositMailer)

        expect(check_deposit.reload).to be_submitted
      end
    end

    it "keeps the reason on a deposit an admin already rejected" do
      check_deposit.update!(status: :rejected, rejection_reason: :poor_image_quality)

      check_deposit.update_from_column_status!("rejected")

      expect(check_deposit.reload.rejection_reason).to eq("poor_image_quality")
    end
  end

  describe "#sync_from_column!" do
    it "applies the status Column has for the deposit" do
      check_deposit = create(:check_deposit, :submitted)
      allow(ColumnService).to receive(:get).with("/transfers/checks/#{check_deposit.column_id}").and_return({ "status" => "rejected" })

      check_deposit.sync_from_column!

      expect(check_deposit.reload).to be_rejected
    end

    it "raises for a deposit that was never submitted to Column" do
      check_deposit = create(:check_deposit)

      expect { check_deposit.sync_from_column! }.to raise_error(ArgumentError)
    end
  end
end
