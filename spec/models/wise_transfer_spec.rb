# frozen_string_literal: true

require "rails_helper"

RSpec.describe WiseTransfer do
  def build_instance(**attrs)
    described_class.new(
      **attrs,
      # Everything below shouldn't be required but we have validation code that
      # assumes these attributes are present.
      event: build(:event),
      recipient_country: :CA
    )
  end

  describe "#wise_id" do
    it "is optional" do
      instance = build_instance(wise_id: nil)
      instance.validate
      expect(instance.errors[:wise_id]).to be_empty
    end

    it "is required if the wise transfer is marked as sent or deposited" do
      ["sent", "deposited"].each do |aasm_state|
        instance = build_instance(wise_id: nil, aasm_state:)
        instance.validate

        expect(instance.errors[:wise_id]).to(
          eq(["can't be blank"]),
          "wise transfer with aasm state #{aasm_state.inspect} should require wise_id"
        )
      end
    end

    it "must be a number" do
      instance = build_instance(wise_id: "NOPE")
      instance.validate
      expect(instance.errors[:wise_id]).to eq(["is not a valid Wise ID"])

      instance.wise_id = "\t1234567890 "
      instance.validate
      expect(instance.errors[:wise_id]).to be_empty
      expect(instance.wise_id).to eq("1234567890")
    end

    it "is automatically normalized from a URL" do
      instance = build_instance(wise_id: " https://wise.com/transactions/activities/by-resource/TRANSFER/1234567890\n")
      instance.validate
      expect(instance.errors[:wise_id]).to be_empty
      expect(instance.wise_id).to eq("1234567890")

      instance.wise_id = "https://wise.com/success/transfer/0987654321"
      instance.validate
      expect(instance.errors[:wise_id]).to be_empty
      expect(instance.wise_id).to eq("0987654321")
    end
  end

  describe "#wise_recipient_id" do
    it "is optional" do
      instance = build_instance(wise_recipient_id: nil)
      instance.validate
      expect(instance.errors[:wise_recipient_id]).to be_empty
    end

    it "is required if the wise transfer is marked as sent or deposited" do
      ["sent", "deposited"].each do |aasm_state|
        instance = build_instance(wise_recipient_id: nil, aasm_state:)
        instance.validate

        expect(instance.errors[:wise_recipient_id]).to(
          eq(["can't be blank"]),
          "wise transfer with aasm state #{aasm_state.inspect} should require wise_recipient_id"
        )
      end
    end

    it "must be a UUID-like string" do
      instance = build_instance(wise_recipient_id: "NOPE")
      instance.validate
      expect(instance.errors[:wise_recipient_id]).to eq(["is not a valid Wise recipient ID"])

      instance.wise_recipient_id = "\t3e219880-5f3e-4230-8a5a-9c8c25af26bb "
      instance.validate
      expect(instance.errors[:wise_recipient_id]).to be_empty
      expect(instance.wise_recipient_id).to eq("3e219880-5f3e-4230-8a5a-9c8c25af26bb")
    end

    it "is automatically normalized from a URL" do
      instance = build_instance(wise_recipient_id: "https://wise.com/recipients/3e219880-5f3e-4230-8a5a-9c8c25af26bb?list=ALL")
      instance.validate
      expect(instance.errors[:wise_recipient_id]).to be_empty
      expect(instance.wise_recipient_id).to eq("3e219880-5f3e-4230-8a5a-9c8c25af26bb")
    end
  end

  describe "#mark_failed!" do
    def create_sent_wise_transfer(event:)
      WiseTransfer.create!(
        event:,
        user: create(:user),
        amount_cents: 100_00,
        currency: "GBP",
        recipient_country: "GB",
        recipient_name: "Fiona Hackworth",
        recipient_email: "fiona@example.com",
        payment_for: "Reimbursement for Test Report.",
        # Set so the after_create hook skips generate_quote!, which would
        # otherwise reach for a live exchange rate.
        quoted_usd_amount_cents: 130_00,
        usd_amount_cents: 130_00,
        wise_id: "1234567890",
        wise_recipient_id: "3e219880-5f3e-4230-8a5a-9c8c25af26bb",
        aasm_state: :sent
      )
    end

    context "when the transfer pays out a reimbursement report" do
      # Payout holdings live on the reimbursement clearinghouse event, which
      # must exist for their pending transaction to be created.
      let(:clearinghouse) { create(:event, id: EventMappingEngine::EventIds::REIMBURSEMENT_CLEARING) }
      let(:wise_transfer) { create_sent_wise_transfer(event: clearinghouse) }
      let!(:payout_holding) do
        Reimbursement::PayoutHolding.create!(
          report: create(:reimbursement_report),
          wise_transfer:,
          amount_cents: 130_00,
          aasm_state: :sent
        )
      end

      it "fails the payout holding so the report can be reversed, and notifies the reimbursee" do
        allow(WiseTransferMailer).to receive(:with).and_call_original

        expect { wise_transfer.mark_failed!("The recipient's account details were invalid") }
          .to have_enqueued_mail(ReimbursementMailer, :wise_transfer_failed)
          .with(params: { reimbursement_payout_holding: payout_holding, reason: "The recipient's account details were invalid" }, args: [])
          .once

        expect(wise_transfer).to be_failed
        expect(wise_transfer.return_reason).to eq("The recipient's account details were invalid")
        expect(wise_transfer.canonical_pending_transaction.reload).to be_declined
        expect(payout_holding.reload).to be_failed
        expect(payout_holding).to be_may_mark_reversed
        expect(WiseTransferMailer).not_to have_received(:with)
      end
    end

    context "when the transfer is not a reimbursement payout" do
      let(:wise_transfer) { create_sent_wise_transfer(event: create(:event)) }

      it "notifies the sender instead" do
        allow(ReimbursementMailer).to receive(:with).and_call_original

        expect { wise_transfer.mark_failed!("Beneficiary account is closed") }
          .to have_enqueued_mail(WiseTransferMailer, :notify_failed)
          .with(params: { wise_transfer:, reason: "Beneficiary account is closed" }, args: [])
          .once

        expect(wise_transfer).to be_failed
        expect(ReimbursementMailer).not_to have_received(:with)
      end
    end
  end
end
