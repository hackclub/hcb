# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardCharge, type: :model do
  describe "creating a RawPendingStripeTransaction" do
    it "creates a CardCharge for the authorization" do
      rpst = create(:raw_pending_stripe_transaction)

      charge = rpst.card_charge
      expect(charge).to be_present
      expect(charge.raw_stripe_transactions).to be_empty
    end

    it "claims an existing charge when the settled transaction arrived first" do
      rst = create(:raw_stripe_transaction, stripe_authorization_id: "iauth_arrived_first")
      charge = rst.card_charge
      expect(charge.raw_pending_stripe_transaction).to be_nil

      rpst = create(:raw_pending_stripe_transaction, stripe_transaction_id: "iauth_arrived_first")

      expect(rpst.card_charge).to eq(charge)
      expect(charge.reload.raw_pending_stripe_transaction).to eq(rpst)
    end
  end

  describe "creating a RawStripeTransaction" do
    it "joins the authorization's charge when it settles" do
      rpst = create(:raw_pending_stripe_transaction, stripe_transaction_id: "iauth_settles")
      rst = create(:raw_stripe_transaction, stripe_authorization_id: "iauth_settles")

      expect(rst.card_charge).to eq(rpst.card_charge)
      expect(rpst.card_charge.raw_stripe_transactions).to contain_exactly(rst)
    end

    it "groups multi-captures and refunds of the same authorization into one charge" do
      rpst = create(:raw_pending_stripe_transaction, stripe_transaction_id: "iauth_multi")
      first_capture = create(:raw_stripe_transaction, stripe_authorization_id: "iauth_multi")
      second_capture = create(:raw_stripe_transaction, stripe_authorization_id: "iauth_multi")

      charge = rpst.card_charge
      expect(charge.raw_stripe_transactions).to contain_exactly(first_capture, second_capture)
    end

    it "creates a standalone charge for a force capture (no authorization)" do
      rst = create(:raw_stripe_transaction, stripe_authorization_id: nil)

      charge = rst.card_charge
      expect(charge).to be_present
      expect(charge.raw_pending_stripe_transaction).to be_nil
      expect(charge.raw_stripe_transactions).to contain_exactly(rst)
    end

    it "does not group force captures with each other" do
      first = create(:raw_stripe_transaction, stripe_authorization_id: nil)
      second = create(:raw_stripe_transaction, stripe_authorization_id: nil)

      expect(first.card_charge).not_to eq(second.card_charge)
    end

    it "groups settled transactions sharing an authorization even before it is imported" do
      first = create(:raw_stripe_transaction, stripe_authorization_id: "iauth_pending_missing")
      second = create(:raw_stripe_transaction, stripe_authorization_id: "iauth_pending_missing")

      expect(first.card_charge).to eq(second.card_charge)
      expect(first.card_charge.raw_pending_stripe_transaction).to be_nil
    end
  end

  describe ".link_raw_pending_stripe_transaction!" do
    it "is idempotent" do
      rpst = create(:raw_pending_stripe_transaction)
      charge = rpst.card_charge

      expect { CardCharge.link_raw_pending_stripe_transaction!(rpst.reload) }.not_to change(CardCharge, :count)
      expect(rpst.card_charge).to eq(charge)
    end
  end

  describe ".link_raw_stripe_transaction!" do
    it "is idempotent" do
      rst = create(:raw_stripe_transaction, stripe_authorization_id: "iauth_idempotent")
      charge = rst.card_charge

      expect { CardCharge.link_raw_stripe_transaction!(rst.reload) }.not_to change(CardCharge, :count)
      expect(rst.reload.card_charge).to eq(charge)
      expect(charge.raw_stripe_transactions.count).to eq(1)
    end
  end

  describe "#failed_verification_checks" do
    it "lists the checks Stripe reported as mismatched when it authorized the charge" do
      rpst = create(:raw_pending_stripe_transaction, stripe_transaction_id: "iauth_verified", stripe_transaction: {
                      "card"              => { "id" => "ic_verified" },
                      "verification_data" => {
                        "address_line1_check"       => "not_provided",
                        "address_postal_code_check" => "mismatch",
                        "cvc_check"                 => "match",
                        "expiry_check"              => "mismatch",
                        "authentication_exemption"  => nil
                      }
                    })
      # Settled transactions carry no verification data; capturing must not hide the authorization's.
      create(:raw_stripe_transaction, stripe_authorization_id: "iauth_verified")

      expect(rpst.card_charge.reload.failed_verification_checks).to contain_exactly("address_postal_code_check", "expiry_check")
    end

    it "is empty when Stripe reported no verification data" do
      rpst = create(:raw_pending_stripe_transaction)

      expect(rpst.card_charge.failed_verification_checks).to eq([])
    end

    it "is empty for a charge that settled without an authorization" do
      rst = create(:raw_stripe_transaction)

      expect(rst.card_charge.failed_verification_checks).to eq([])
    end
  end

  describe "#refunded_amount_cents" do
    it "sums the charge's refunds, leaving the captures out" do
      rpst = create(:raw_pending_stripe_transaction, stripe_transaction_id: "iauth_refunded")
      create(:raw_stripe_transaction, stripe_authorization_id: "iauth_refunded", amount_cents: -1500)
      create(:raw_stripe_transaction, :refund, stripe_authorization_id: "iauth_refunded", amount_cents: 1500)
      create(:raw_stripe_transaction, :refund, stripe_authorization_id: "iauth_refunded", amount_cents: 500)

      expect(rpst.card_charge.reload.refunded_amount_cents).to eq(2000)
    end

    it "is zero for a charge that hasn't been refunded" do
      rpst = create(:raw_pending_stripe_transaction, stripe_transaction_id: "iauth_unrefunded")
      create(:raw_stripe_transaction, stripe_authorization_id: "iauth_unrefunded", amount_cents: -1500)

      expect(rpst.card_charge.reload.refunded_amount_cents).to eq(0)
    end
  end

  describe "#merchant_amount" do
    it "is what the merchant charged, in the merchant's currency" do
      rpst = create(:raw_pending_stripe_transaction, stripe_transaction: {
                      "card"              => { "id" => "ic_eur" },
                      "merchant_amount"   => -1234,
                      "merchant_currency" => "eur"
                    })

      expect(rpst.card_charge.merchant_amount).to eq(Money.from_cents(1234, "EUR"))
      expect(rpst.card_charge).to be_foreign_currency
    end

    it "prefers the settled transaction's amount over the authorization's" do
      rpst = create(:raw_pending_stripe_transaction, stripe_transaction_id: "iauth_eur_settled", stripe_transaction: {
                      "card"              => { "id" => "ic_eur_settled" },
                      "merchant_amount"   => -1000,
                      "merchant_currency" => "eur"
                    })
      create(:raw_stripe_transaction, stripe_authorization_id: "iauth_eur_settled", stripe_transaction: {
               "card"              => "ic_eur_settled",
               "authorization"     => "iauth_eur_settled",
               "merchant_amount"   => -1050,
               "merchant_currency" => "eur"
             })

      expect(rpst.card_charge.reload.merchant_amount).to eq(Money.from_cents(1050, "EUR"))
    end

    it "is not foreign when the merchant charged in USD" do
      rpst = create(:raw_pending_stripe_transaction, stripe_transaction: {
                      "card"              => { "id" => "ic_usd" },
                      "merchant_amount"   => -1234,
                      "merchant_currency" => "usd"
                    })

      expect(rpst.card_charge.merchant_amount).to eq(Money.from_cents(1234, "USD"))
      expect(rpst.card_charge).not_to be_foreign_currency
    end

    it "is nil when Stripe reported no merchant amount" do
      rpst = create(:raw_pending_stripe_transaction)

      expect(rpst.card_charge.merchant_amount).to be_nil
      expect(rpst.card_charge).not_to be_foreign_currency
    end

    it "is nil when the merchant currency is unknown" do
      rpst = create(:raw_pending_stripe_transaction, stripe_transaction: {
                      "card"              => { "id" => "ic_unknown" },
                      "merchant_amount"   => -1234,
                      "merchant_currency" => "xyz"
                    })

      expect(rpst.card_charge.merchant_amount).to be_nil
    end
  end

  describe "#stripe_card" do
    it "is set automatically when the charge is created" do
      rst = create(:raw_stripe_transaction)
      charge = rst.card_charge

      expect(charge.stripe_card_id).to eq(rst.stripe_card.id)
      expect(charge.stripe_card).to eq(rst.stripe_card)
    end
  end
end
