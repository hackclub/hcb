# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardChargeMailer, type: :mailer do
  # A charge that settled and was then refunded in full.
  def build_ledger_item(user:, merchant_name: "Merchant", verification_data: {}, amount_cents: -12_34)
    stripe_cardholder = create(:stripe_cardholder, user:, stripe_billing_address_postal_code: "90069")
    stripe_card = create(:stripe_card, :with_stripe_id, stripe_cardholder:)
    raw_pending_stripe_transaction = create(:raw_pending_stripe_transaction, amount_cents:, date_posted: Date.current, stripe_transaction: {
                                              "card"                 => { "id" => stripe_card.stripe_id },
                                              "approved"             => true,
                                              "status"               => "closed",
                                              "authorization_method" => "online",
                                              "merchant_data"        => { "name" => merchant_name },
                                              "verification_data"    => verification_data,
                                              "request_history"      => [{ "amount" => -amount_cents, "approved" => true, "reason" => "card_active" }]
                                            })
    raw_stripe_transaction = create(:raw_stripe_transaction, stripe_card:, amount_cents:,
                                                             stripe_authorization_id: raw_pending_stripe_transaction.stripe_transaction_id,
                                                             stripe_transaction: {
                                                               "card"          => stripe_card.stripe_id,
                                                               "type"          => "capture",
                                                               "merchant_data" => { "name" => merchant_name }
                                                             })
    card_charge = raw_stripe_transaction.card_charge

    # A reversed charge's refund cancels out its capture, so the item nets to zero.
    item = Ledger::Item.new(amount_cents: 0, memo: "Test", datetime: Time.current, linked_object: card_charge)
    item.save(validate: false)
    item.update_columns(amount_cents: 0, status: "reversed")
    item
  end

  # An authorization that Stripe released before the merchant captured it.
  def build_released_ledger_item(user:, amount_cents: -45_00)
    stripe_cardholder = create(:stripe_cardholder, user:)
    stripe_card = create(:stripe_card, :with_stripe_id, stripe_cardholder:)
    raw_pending_stripe_transaction = create(:raw_pending_stripe_transaction, amount_cents:, date_posted: Date.current, stripe_transaction: {
                                              "card"                 => { "id" => stripe_card.stripe_id },
                                              "approved"             => true,
                                              "status"               => "reversed",
                                              "authorization_method" => "online",
                                              "merchant_data"        => { "name" => "goBILDA" },
                                              "request_history"      => [{ "amount" => -amount_cents, "approved" => true, "reason" => "card_active" }]
                                            })
    canonical_pending_transaction = create(:canonical_pending_transaction, raw_pending_stripe_transaction:, amount_cents:)
    item = canonical_pending_transaction.reload.ledger_item

    # Stripe zeroes a released authorization's amount, the pending transaction
    # import copies that onto the canonical pending transaction, and the
    # declined pending transaction no longer counts towards the item.
    raw_pending_stripe_transaction.update_columns(amount_cents: 0)
    canonical_pending_transaction.update_columns(amount_cents: 0)
    item.update_columns(amount_cents: 0, status: "released")
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

    it "says what was authorized when the authorization was released before it was captured" do
      user = create(:user)
      ledger_item = build_released_ledger_item(user:, amount_cents: -45_00)

      mail = described_class.with(ledger_item:).reversed

      expect(mail.subject).to eq("Your charge at goBILDA was reversed")
      expect(mail.body.encoded).to include("$45.00")
      expect(mail.body.encoded).not_to include("$0.00")
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

    it "does not send when the charge was under $1" do
      user = create(:user)
      ledger_item = build_ledger_item(user:, amount_cents: -99)

      mail = described_class.with(ledger_item:).reversed

      expect { mail.deliver_now }.not_to(change { ActionMailer::Base.deliveries.count })
    end

    it "sends when the charge was exactly $1" do
      user = create(:user)
      ledger_item = build_ledger_item(user:, amount_cents: -1_00)

      mail = described_class.with(ledger_item:).reversed

      expect { mail.deliver_now }.to change { ActionMailer::Base.deliveries.count }.by(1)
      expect(mail.body.encoded).to include("$1.00")
    end

    it "only lists the reason that actually failed, not the others" do
      user = create(:user)
      ledger_item = build_ledger_item(user:, verification_data: { "address_postal_code_check" => "mismatch" })

      mail = described_class.with(ledger_item:).reversed

      expect(mail.body.encoded).to include("the zip code used at")
      expect(mail.body.encoded).not_to include("CVC")
      expect(mail.body.encoded).not_to include("expiration date")
      expect(mail.body.encoded.scan("didn't match your").size).to eq(1)
    end
  end
end
