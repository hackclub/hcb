# frozen_string_literal: true

require "rails_helper"

RSpec.describe LegalEntity::PayoutMethod::WiseTransfer, type: :model do
  let(:event) { create(:event) }

  subject(:payout_method) do
    build(:wise_transfer_payout_method_details, currency: "AED")
  end

  describe "#create_transfer" do
    # $332 in a payment must be paid out as its AED-equivalent, not 332 AED.
    it "converts the USD payment amount into the recipient's local currency" do
      allow(MoneyService).to receive(:convert_from_usd_wise).with(332_00, "AED").and_return(1_218_44)

      transfer = payout_method.create_transfer(
        event,
        amount: 332_00,
        payment_for: "Payment for \"Engineering hours\".",
        recipient_name: "Jane Doe",
        recipient_email: "jane@example.com",
        currency: "USD",
        user: create(:user)
      )

      expect(transfer.currency).to eq("AED")
      expect(transfer.amount_cents).to eq(1_218_44)
    end
  end
end
