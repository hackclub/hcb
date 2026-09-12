# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardChargeMailer, type: :mailer do
  def build_ledger_item(user:, merchant_name: "Merchant", verification_data: {}, amount_cents: -12_34)
    stripe_cardholder = create(:stripe_cardholder, user:, stripe_billing_address_postal_code: "90069")
    stripe_card = create(:stripe_card, :with_stripe_id, stripe_cardholder:)
    raw_stripe_transaction = create(:raw_stripe_transaction, stripe_card:, stripe_transaction: {
      "card" => stripe_card.stripe_id,
      "merchant_data" => { "name" => merchant_name },
      "verification_data" => verification_data
    })
    card_charge = raw_stripe_transaction.card_charge

    item = Ledger::Item.new(amount_cents:, memo: "Test", datetime: Time.current, linked_object: card_charge)
    item.save(validate: false)
    item.update_columns(amount_cents:)
    item
  end

  describe "#reversed" do
    it "emails the cardholder with the merchant, amount, and a link to the transaction" do
      user = create(:user)
      ledger_item = build_ledger_item(user:, merchant_name: "goBILDA", amount_cents: -45_00)

      mail = described_class.with(ledger_item:).reversed

      expect(mail.to).to eq([user.email])
      expect(mail.subject).to eq("Your charge at goBILDA was reversed")
      expect(mail.body.encoded).to include("$45.00")
      expect(mail.body.encoded).to include(ledger_item_url(ledger_item))
    end

    it "does not mention troubleshooting tips when there is no verification mismatch" do
      user = create(:user)
      ledger_item = build_ledger_item(user:, verification_data: { "address_postal_code_check" => "match" })

      mail = described_class.with(ledger_item:).reversed

      expect(mail.body.encoded).not_to include("Troubleshooting tips")
    end

    it "suggests the correct zip code when Stripe reports an address mismatch" do
      user = create(:user)
      ledger_item = build_ledger_item(user:, verification_data: { "address_postal_code_check" => "mismatch" })

      mail = described_class.with(ledger_item:).reversed

      expect(mail.body.encoded).to include("Troubleshooting tips")
      expect(mail.body.encoded).to include("90069")
    end

    it "does not send when the cardholder disabled charge notifications" do
      user = create(:user, charge_notifications: :nothing)
      ledger_item = build_ledger_item(user:)

      mail = described_class.with(ledger_item:).reversed

      expect { mail.deliver_now }.not_to(change { ActionMailer::Base.deliveries.count })
    end
  end
end