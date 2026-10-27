# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardChargeMailer, type: :mailer do
  def build_ledger_item(user:, merchant_name: "Merchant", verification_data: {}, amount_cents: -12_34,
                        spending_limit_amount: nil, spending_limit_interval: nil)
    stripe_cardholder = create(:stripe_cardholder, user:, stripe_billing_address_postal_code: "90069")
    stripe_card = create(:stripe_card, :with_stripe_id, stripe_cardholder:, spending_limit_amount:, spending_limit_interval:)
    raw_stripe_transaction = create(:raw_stripe_transaction, stripe_card:, stripe_transaction: {
                                      "card"              => stripe_card.stripe_id,
                                      "merchant_data"     => { "name" => merchant_name },
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

      expect(mail.body.encoded).not_to include("What went wrong")
    end

    it "shows what went wrong when Stripe reports a zip code mismatch" do
      user = create(:user)
      ledger_item = build_ledger_item(user:, verification_data: { "address_postal_code_check" => "mismatch" })

      mail = described_class.with(ledger_item:).reversed

      expect(mail.body.encoded).to include("What went wrong")
      expect(mail.body.encoded).to include("the zip code used at")
      expect(mail.body.encoded).to include("/my/settings/address")
    end

    it "does not send when the cardholder disabled charge notifications" do
      user = create(:user, charge_notifications: :nothing)
      ledger_item = build_ledger_item(user:)

      mail = described_class.with(ledger_item:).reversed

      expect { mail.deliver_now }.not_to(change { ActionMailer::Base.deliveries.count })
    end

    it "only lists the reason that actually failed, not the others" do
      user = create(:user)
      ledger_item = build_ledger_item(user:, verification_data: { "address_postal_code_check" => "mismatch" })

      mail = described_class.with(ledger_item:).reversed

      expect(mail.body.encoded).to include("the zip code used at")
      expect(mail.body.encoded).not_to include("CVC")
      expect(mail.body.encoded).not_to include("expiration date")
      expect(mail.body.encoded).not_to include("spending limit")
      expect(mail.body.encoded).not_to include("enough balance")
      expect(mail.body.encoded.scan("didn't match your").size).to eq(1)
    end

    it "mentions insufficient balance when the event's balance can't cover the charge, even with no verification mismatch" do
      user = create(:user)
      ledger_item = build_ledger_item(user:, amount_cents: -50_00)
      allow_any_instance_of(Event).to receive(:balance_v2_cents).and_return(-10_00)

      mail = described_class.with(ledger_item:).reversed

      expect(mail.body.encoded).to include("What went wrong")
      expect(mail.body.encoded).to include("enough balance")
    end

    it "mentions the spending limit when a per-authorization limit is exceeded, even with no verification mismatch" do
      user = create(:user)
      ledger_item = build_ledger_item(user:, amount_cents: -50_00, spending_limit_amount: 10_00,
                                      spending_limit_interval: :per_authorization)

      mail = described_class.with(ledger_item:).reversed

      expect(mail.body.encoded).to include("What went wrong")
      expect(mail.body.encoded).to include("spending limit")
    end
  end
end
