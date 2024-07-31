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
end
