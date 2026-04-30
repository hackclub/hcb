# frozen_string_literal: true

require "rails_helper"

RSpec.describe Payment do
  let(:attacker_event) do
    e = create(:event)
    create(:canonical_pending_transaction, amount_cents: 100_000, event: e, fronted: true)
    e
  end
  let(:victim_event) { create(:event) }

  describe "same-event payment recipient validation" do
    context "AchTransfer" do
      it "rejects a PaymentRecipient that belongs to a different event" do
        victim_recipient = create(:payment_recipient, event: victim_event)

        transfer = build(:ach_transfer, :without_payment_details, event: attacker_event, payment_recipient: victim_recipient)

        expect(transfer).not_to be_valid
        expect(transfer.errors[:base]).to include("Recipient must be in the same org")
      end

      it "accepts a PaymentRecipient that belongs to the same event" do
        own_recipient = create(:payment_recipient, event: attacker_event)

        transfer = build(:ach_transfer, :without_payment_details, event: attacker_event, payment_recipient: own_recipient)

        expect(transfer).to be_valid
      end
    end

    context "IncreaseCheck" do
      it "rejects a PaymentRecipient that belongs to a different event" do
        victim_recipient = create(
          :payment_recipient,
          event: victim_event,
          payment_model: "IncreaseCheck",
          address_line1: "1 Main",
          address_line2: "",
          address_city: "City",
          address_state: "CA",
          address_zip: "94000"
        )

        check = IncreaseCheck.new(
          event: attacker_event,
          payment_recipient: victim_recipient,
          amount: 100,
          memo: "test",
          payment_for: "test",
          recipient_name: "Recipient",
          recipient_email: "recipient@example.com"
        )

        expect(check).not_to be_valid
        expect(check.errors[:base]).to include("Recipient must be in the same org")
      end
    end

    context "Wire" do
      before do
        stub_request(:get, /api\.column\.com\/institutions/)
          .to_return(
            status: 200,
            body: '{"country_code":"US"}',
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "rejects a PaymentRecipient that belongs to a different event" do
        victim_recipient = create(
          :payment_recipient,
          event: victim_event,
          payment_model: "Wire",
          account_number: "12345",
          bic_code: "BOFAUS3N",
          address_line1: "1 Main",
          address_line2: "",
          address_city: "City",
          address_state: "CA",
          address_postal_code: "94000",
          recipient_country: "US",
          recipient_information: {}
        )

        wire = Wire.new(
          event: attacker_event,
          payment_recipient: victim_recipient,
          user: create(:user),
          amount_cents: 100,
          memo: "test",
          payment_for: "test",
          recipient_name: "Recipient",
          recipient_email: "recipient@example.com",
          currency: "USD"
        )

        expect(wire).not_to be_valid
        expect(wire.errors[:base]).to include("Recipient must be in the same org")
      end
    end
  end
end
