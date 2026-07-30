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
      ach_transfer.update(payment_for: "a" * 256)

      expect(ach_transfer.errors[:payment_for]).to include("is too long (maximum is 255 characters)")
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
end
