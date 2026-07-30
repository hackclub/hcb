# frozen_string_literal: true

require "rails_helper"

RSpec.describe LegalEntity::PayoutMethod::AchTransfer, type: :model do
  let(:event) { create(:event) }

  subject(:payout_method) do
    build(:ach_transfer_payout_method_details)
  end

  describe "#create_transfer" do
    before do
      allow(ColumnService).to receive(:get).and_return({ "full_name" => "Bank of Wizardry" })
    end

    def build_transfer(payment_for:)
      payout_method.create_transfer(
        event,
        amount: 332_00,
        payment_for:,
        recipient_name: "Jane Doe",
        recipient_email: "jane@example.com",
        user: create(:user)
      )
    end

    # `payment_for` is built from unbounded text (a reimbursement report's name,
    # a payment's purpose), so it has to fit within AchTransfer's length limit.
    it "truncates payment_for to the maximum AchTransfer allows" do
      max = AchTransfer::PAYMENT_FOR_MAX_LENGTH
      transfer = build_transfer(payment_for: "a" * (max + 45))

      expect(transfer.payment_for).to eq("a" * max)
    end

    it "leaves a payment_for within the limit untouched" do
      transfer = build_transfer(payment_for: "Payment for \"Engineering hours\".")

      expect(transfer.payment_for).to eq("Payment for \"Engineering hours\".")
    end

    it "accepts a nil payment_for" do
      transfer = build_transfer(payment_for: nil)

      expect(transfer.payment_for).to be_nil
    end
  end
end
