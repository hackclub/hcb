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

  describe "#mark_failed!" do
    include ActiveJob::TestHelper

    def create_deposited_transfer
      transfer = described_class.create!(
        event: create(:event),
        user: create(:user),
        aasm_state: "deposited",
        amount_cents: 100_00,
        currency: "GBP",
        recipient_country: "GB",
        recipient_name: "Fiona Hackworth",
        recipient_email: "fiona@example.com",
        payment_for: "Reimbursement",
        wise_id: "1234567",
        wise_recipient_id: "0199a1f0-7c3a-4a0b-9b2e-6d1f8a3c5e47",
        quoted_usd_amount_cents: 130_00,
        usd_amount_cents: 130_00
      )
      outgoing = create(:canonical_transaction, amount_cents: -130_00)
      CanonicalPendingTransactionService::Settle.new(canonical_transaction: outgoing, canonical_pending_transaction: transfer.canonical_pending_transaction).run!
      transfer
    end

    # Payout holdings create a pending transaction on the clearinghouse event
    # on create, so insert one directly, as other specs do.
    def attach_payout_holding(transfer, aasm_state: "sent")
      report = create(:reimbursement_report, aasm_state: :reimbursed)
      Reimbursement::PayoutHolding.insert_all([{
                                                reimbursement_reports_id: report.id, amount_cents: 130_00, wise_transfer_id: transfer.id,
                                                aasm_state:, created_at: Time.current, updated_at: Time.current
                                              }])
      Reimbursement::PayoutHolding.find_by!(wise_transfer_id: transfer.id)
    end

    let!(:system_user) { create(:user, id: User::SYSTEM_USER_ID) }

    it "keeps the payout holding in the clearinghouse without cancelling the report until a refund arrives" do
      transfer = create_deposited_transfer
      payout_holding = attach_payout_holding(transfer)
      expect_any_instance_of(Reimbursement::PayoutHolding).not_to receive(:reverse!)

      expect {
        transfer.mark_failed!("Account closed")
      }.to have_enqueued_mail(ReimbursementMailer, :wise_transfer_failed)
        .with(params: a_hash_including(reason: "Account closed", cancelled: false), args: [])

      expect(transfer.reload).to be_failed
      expect(transfer.return_reason).to eq("Account closed")
      expect(transfer.canonical_pending_transaction.reload).not_to be_declined
      expect(payout_holding.reload).to be_failed
      expect(payout_holding.report.comments).to be_empty
    end

    it "doesn't email about the failure when a refund is being mapped, since the cancellation emails instead" do
      transfer = create_deposited_transfer
      attach_payout_holding(transfer)

      expect {
        transfer.mark_failed!("Account closed", refunded: true)
      }.not_to have_enqueued_mail(ReimbursementMailer, :wise_transfer_failed)

      expect(transfer.reload).to be_failed
      expect(transfer.return_reason).to eq("Account closed")
    end

    describe "#cancel_reimbursement_for_refund" do
      it "cancels the reimbursement report, returning the funds" do
        transfer = create_deposited_transfer
        payout_holding = attach_payout_holding(transfer)
        transfer.mark_failed!("Account closed", refunded: true)
        reversed = []
        allow_any_instance_of(Reimbursement::PayoutHolding).to receive(:reverse!) { |holding| reversed << holding.id }

        expect {
          transfer.cancel_reimbursement_for_refund("Account closed")
        }.to have_enqueued_mail(ReimbursementMailer, :wise_transfer_failed)
          .with(params: a_hash_including(reason: "Account closed", cancelled: true), args: [])

        expect(reversed).to eq([payout_holding.id])

        report = payout_holding.report
        comment = report.comments.sole
        expect(comment.user).to eq(system_user)
        expect(comment.content).to include("cancelled because the transfer was returned: Account closed")
        expect(comment.content).to include("returned to #{report.event.name} within 1 business day")
      end

      it "does nothing for a transfer that isn't a reimbursement" do
        transfer = create_deposited_transfer

        expect {
          transfer.cancel_reimbursement_for_refund("Account closed")
        }.not_to have_enqueued_mail(ReimbursementMailer, :wise_transfer_failed)
      end
    end

    it "leaves the payout failed for ops to cancel when it can't be cancelled yet, and never retries it" do
      transfer = create_deposited_transfer
      payout_holding = attach_payout_holding(transfer)
      transfer.mark_failed!("Account closed", refunded: true)
      allow_any_instance_of(Reimbursement::PayoutHolding).to receive(:reverse!).and_raise(ArgumentError, "must have settled expense payouts")

      expect {
        transfer.cancel_reimbursement_for_refund("Account closed")
      }.to have_enqueued_mail(ReimbursementMailer, :wise_transfer_failed)
        .with(params: a_hash_including(cancelled: false), args: [])

      expect(payout_holding.reload).to be_failed
      expect(payout_holding).not_to be_awaiting_wise_transfer
      expect(payout_holding.report.comments).to be_empty

      # Unlike a failed wire or ACH, updating the payout method doesn't settle
      # it again for a resend.
      LegalEntity::PayoutMethodService::Update.new(
        legal_entity: payout_holding.report.user.personal_legal_entity,
        details_type: "LegalEntity::PayoutMethod::WiseTransfer",
        details_attrs: {
          address_line1: "1 Main St", address_city: "Toronto", address_state: "ON",
          address_postal_code: "M5V2T6", recipient_country: "CA", currency: "CAD"
        }
      ).run!

      expect(payout_holding.reload).to be_failed
    end

    it "notifies the sender when there's no reimbursement or payment attached" do
      transfer = create_deposited_transfer

      expect {
        transfer.mark_failed!("Account closed")
      }.to have_enqueued_mail(WiseTransferMailer, :notify_failed)

      expect(transfer.reload).to be_failed
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
          # Marking it failed never cancels the report; only a mapped refund does.
          .with(params: { reimbursement_payout_holding: payout_holding, reason: "The recipient's account details were invalid", cancelled: false }, args: [])
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
