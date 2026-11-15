# frozen_string_literal: true

require "rails_helper"

RSpec.describe AchTransfer, type: :model do
  let(:event) {
    event = create(:event)
    create(:canonical_pending_transaction, amount_cents: 1000, event:, fronted: true)
    event
  }
  let(:ach_transfer) { create(:ach_transfer, event:) }

  context "when created without a payment recipient" do
    it "creates one" do
      expect(ach_transfer.payment_recipient).not_to be_nil

      expect(ach_transfer).to be_valid
    end

    it "copies over payment details" do
      expect(ach_transfer.payment_recipient.name).to           eq(ach_transfer.recipient_name)
      expect(ach_transfer.payment_recipient.account_number).to eq(ach_transfer.account_number)
      expect(ach_transfer.payment_recipient.routing_number).to eq(ach_transfer.routing_number)
      expect(ach_transfer.payment_recipient.bank_name).to      eq(ach_transfer.bank_name)

      expect(ach_transfer).to be_valid
    end
  end

  context "when created with a payment recipient" do
    it "copies over payment details to transfer when none provided" do
      recipient = create(:payment_recipient, event:)
      expect {
        ach_transfer = create(:ach_transfer, :without_payment_details, payment_recipient: recipient, event:)

        expect(recipient.name).to           eq(ach_transfer.recipient_name)
        expect(recipient.account_number).to eq(ach_transfer.account_number)
        expect(recipient.routing_number).to eq(ach_transfer.routing_number)
        expect(recipient.bank_name).to      eq(ach_transfer.bank_name)
      }.not_to change(recipient, :account_number)
    end

    it "updates payment recipient when details change" do
      recipient = create(:payment_recipient, event:)
      original_account_number = recipient.account_number
      new_account_number = Faker::Bank.account_number
      expect {
        ach_transfer = create(:ach_transfer, account_number: new_account_number, payment_recipient: recipient, event:)
        recipient.reload

        expect(recipient.name).to           eq(ach_transfer.recipient_name)
        expect(recipient.account_number).to eq(ach_transfer.account_number)
        expect(recipient.routing_number).to eq(ach_transfer.routing_number)
        expect(recipient.bank_name).to      eq(ach_transfer.bank_name)
      }.to change(recipient, :account_number).from(original_account_number).to(new_account_number)
    end
  end

  describe "payment_for validation" do
    it "allows a payment_for of 255 characters" do
      ach_transfer = build(:ach_transfer, event:, payment_for: "a" * 255)

      expect(ach_transfer).to be_valid
    end

    it "rejects a payment_for longer than 255 characters" do
      ach_transfer = build(:ach_transfer, event:, payment_for: "a" * 256)

      expect(ach_transfer).not_to be_valid
      expect(ach_transfer.errors[:payment_for]).to include("is too long (maximum is 255 characters)")
    end

    it "rejects a payment_for that is changed to be longer than 255 characters" do
      expect(ach_transfer.update(payment_for: "a" * 256)).to be false

      expect(ach_transfer.errors[:payment_for]).to include("is too long (maximum is 255 characters)")
      expect(ach_transfer.reload.payment_for).to be_nil
    end

    it "allows saving an existing record whose payment_for is already too long" do
      ach_transfer.update_column(:payment_for, "a" * 256)

      expect(ach_transfer.reload.update(recipient_name: "Fiona Hackworth")).to be true
    end

    it "allows transitioning an existing record whose payment_for is already too long" do
      ach_transfer.update_column(:payment_for, "a" * 256)

      expect { ach_transfer.reload.mark_rejected! }.to change(ach_transfer, :aasm_state).to("rejected")
    end
  end

  describe ".truncate_payment_for" do
    it "shortens text that exceeds the limit" do
      truncated = described_class.truncate_payment_for("a" * 5_000)

      expect(truncated.length).to eq(255)
    end

    it "produces text that satisfies the payment_for validation" do
      ach_transfer = build(:ach_transfer, event:, payment_for: described_class.truncate_payment_for("a" * 5_000))
      ach_transfer.validate

      expect(ach_transfer.errors[:payment_for]).to be_empty
    end

    it "leaves text within the limit untouched" do
      expect(described_class.truncate_payment_for("Shipment of potions")).to eq("Shipment of potions")
    end

    it "accepts nil" do
      expect(described_class.truncate_payment_for(nil)).to be_nil
    end
  end

  describe "#send_ach_transfer!" do
    before do
      allow(ColumnService).to receive(:post).with(/\/account-numbers\z/, anything).and_return(
        { "id" => "acno_1234", "account_number" => "1234", "routing_number" => "1234", "bic" => "1234" }
      )
      allow(ColumnService).to receive(:post).with("/transfers/ach", anything).and_return({ "id" => "acht_1234" })
    end

    # Records predating the length validation are exempt from it, so the
    # description has to be trimmed here too or Column rejects the transfer.
    it "truncates an existing over-long payment_for before sending it to Column" do
      ach_transfer.update_column(:payment_for, "a" * 300)

      ach_transfer.reload.send_ach_transfer!

      expect(ColumnService).to have_received(:post).with(
        "/transfers/ach", hash_including(description: AchTransfer.truncate_payment_for("a" * 300))
      )
    end
  end

  describe "public activity" do
    it "attributes creation to the transfer creator when no controller is present" do
      creator = create(:user)

      transfer = PublicActivity.with_tracking do
        create(:ach_transfer, event:, creator:)
      end

      activity = PublicActivity::Activity.find_by!(trackable: transfer, key: "ach_transfer.create")
      expect(activity.owner).to eq(creator)
    end
  end

  describe "invoiced_at validation" do
    it "allows invoiced_at to be nil" do
      ach_transfer = build(:ach_transfer, event:, invoiced_at: nil)
      expect(ach_transfer).to be_valid
    end

    it "allows invoiced_at to be on the same day as creation" do
      ach_transfer = build(:ach_transfer, event:, invoiced_at: Date.current)
      expect(ach_transfer).to be_valid
    end

    it "allows invoiced_at to be before the creation date" do
      ach_transfer = build(:ach_transfer, event:, invoiced_at: 1.day.ago.to_date)
      expect(ach_transfer).to be_valid
    end

    it "rejects invoiced_at when it's after the creation date" do
      future_date = 1.day.from_now.to_date
      ach_transfer = build(:ach_transfer, event:, invoiced_at: future_date)

      expect(ach_transfer).not_to be_valid
      expect(ach_transfer.errors[:invoiced_at]).to include("cannot be after the transfer creation date")
    end
  end
  describe "scheduled transfers" do
    let(:event) { create(:event, :with_positive_balance) }
    let(:scheduled_transfer) { create(:ach_transfer, event:, scheduled_on: 1.week.from_now.to_date) }

    def import_pending_transaction(ach_transfer)
      # What AchTransfer::DailyJob's send, then the nightly import, do once the
      # scheduled day arrives.
      rpoat = PendingTransactionEngine::RawPendingOutgoingAchTransactionService::OutgoingAch::ImportSingle.new(ach_transfer:).run
      PendingTransactionEngine::CanonicalPendingTransactionService::ImportSingle::OutgoingAch.new(raw_pending_outgoing_ach_transaction: rpoat).run
    end

    it "eagerly create an intended ledger item instead of a pending transaction" do
      expect(scheduled_transfer.canonical_pending_transaction).to be_nil

      item = scheduled_transfer.ledger_item
      expect(item).to be_present
      expect(item.status).to eq("intended")
      expect(item.amount_cents).to eq(0)
      expect(item.memo).to eq("ACH to #{scheduled_transfer.recipient_name}")
      expect(item.hcb_code).to eq(scheduled_transfer.local_hcb_code)
      expect(item.author).to eq(scheduled_transfer.creator)
      # intended_at captures the creation time and is preserved through refresh!.
      expect(item.intended_at).to be_within(1.second).of(scheduled_transfer.created_at)
      expect(item.datetime).to be_within(1.second).of(scheduled_transfer.created_at)
      # Mapped to the event's ledger via the linked object, even without a CPT.
      expect(item.primary_ledger).to eq(event.ledger)
    end

    it "reuse the intended item when the pending transaction is imported after sending" do
      item = scheduled_transfer.ledger_item

      cpt = import_pending_transaction(scheduled_transfer)

      expect(cpt.reload.ledger_item).to eq(item)
      expect(Ledger::Item.where(linked_object: scheduled_transfer).count).to eq(1)
      item.reload
      expect(item.status).to eq("pending")
      expect(item.amount_cents).to eq(-scheduled_transfer.amount)
      expect(item.intended_at).to be_nil
    end

    it "show the intended item as rejected when canceled before being sent" do
      item = scheduled_transfer.ledger_item

      scheduled_transfer.mark_rejected!

      expect(item.reload.status).to eq("rejected")
    end

    it "don't apply to a transfer sent right away, whose pending transaction creates the item" do
      transfer = create(:ach_transfer, event:)

      expect(transfer.canonical_pending_transaction).to be_present
      expect(transfer.reload.ledger_item).to eq(transfer.canonical_pending_transaction.ledger_item)
      expect(Ledger::Item.where(linked_object: transfer).count).to eq(1)
    end
  end
end
