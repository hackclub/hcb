# frozen_string_literal: true

require "rails_helper"

FactoryBot.define do
  factory :stripe_authorization do
    amount { 0 }
    approved { true }
    merchant_data do
      {
        category: "grocery_stores_supermarkets",
        network_id: "1234567890",
        name: "HCB-TEST"
      }
    end
    pending_request do
      {
        amount: 1000,
      }
    end
  end
end

RSpec.describe StripeAuthorizationService::Webhook::HandleIssuingAuthorizationRequest, type: :model do
  let(:event) { create(:event) }
  let(:stripe_card) { create(:stripe_card, :with_stripe_id, event:) }
  let(:service) { StripeAuthorizationService::Webhook::HandleIssuingAuthorizationRequest.new(stripe_event: { data: { object: attributes_for(:stripe_authorization, card: { id: stripe_card.stripe_id }) } }) }

  it "declines with no funds" do
    expect(service.run).to be(false)
    expect(service.declined_reason).to eq("inadequate_balance")
  end

  it "declines when insufficient funds" do
    create(:canonical_pending_transaction, amount_cents: 999, event:, fronted: true)
    expect(service.run).to be(false)
    expect(service.declined_reason).to eq("inadequate_balance")
  end

  it "approves when sufficient funds" do
    create(:canonical_pending_transaction, amount_cents: 1000, event:, fronted: true)
    expect(service.run).to be(true)
  end

  context "card grants" do
    let(:event) { create(:event, :card_grant_event) }
    before(:example) { create(:canonical_pending_transaction, amount_cents: 10000, event:, fronted: true ) }

    def create_service(stripe_card: card_grant.stripe_card, amount: 1000)
      StripeAuthorizationService::Webhook::HandleIssuingAuthorizationRequest.new(stripe_event: { data: { object: attributes_for(:stripe_authorization, card: { id: stripe_card.stripe_id }, pending_request: { amount: }) } })
    end

    it "approves" do
      card_grant = create(:card_grant, event:, amount_cents: 1000)
      service = create_service(stripe_card: card_grant.stripe_card)
      expect(service.run).to be(true)
    end

    it "declines when insufficient funds" do
      card_grant = create(:card_grant, event:, amount_cents: 1000)
      service = create_service(stripe_card: card_grant.stripe_card, amount: 1001)
      expect(service.run).to be(false)
      expect(service.declined_reason).to eq("inadequate_balance")
    end

    context "when category locked" do
      it "declines when wrong category" do
        card_grant = create(:card_grant, event:, amount_cents: 1000, category_lock: ["not_grocery_stores_supermarkets", "another_category"])
        service = create_service(amount: 1000, stripe_card: card_grant.stripe_card)
        expect(service.run).to be(false)
        expect(service.declined_reason).to eq("merchant_not_allowed")
      end

      it "approves when correct category" do
        card_grant = create(:card_grant, event:, amount_cents: 1000, category_lock: ["not_grocery_stores_supermarkets", "another_category", "grocery_stores_supermarkets"])
        service = create_service(amount: 1000, stripe_card: card_grant.stripe_card)
        expect(service.run).to be(true)
      end
    end

    context "when merchant locked" do
      it "declines when wrong merchant" do
        card_grant = create(:card_grant, event:, amount_cents: 1000, merchant_lock: ["203948", "293847"])
        service = create_service(amount: 1000, stripe_card: card_grant.stripe_card)
        expect(service.run).to be(false)
        expect(service.declined_reason).to eq("merchant_not_allowed")
      end

      it "approves when correct merchant" do
        card_grant = create(:card_grant, event:, amount_cents: 1000, merchant_lock: ["203948", "293847", "1234567890"])
        service = create_service(amount: 1000, stripe_card: card_grant.stripe_card)
        expect(service.run).to be(true)
      end
    end

    context "when keyword locked" do
      it "declines w/ an invalid merchant name" do
        card_grant = create(:card_grant, event:, amount_cents: 1000, keyword_lock: "\\ASVB-[a-zA-Z]*\\z")
        service = create_service(amount: 1000, stripe_card: card_grant.stripe_card)
        expect(service.run).to be(false)
        expect(service.declined_reason).to eq("merchant_not_allowed")
      end

      it "approves w/ a valid merchant name" do
        card_grant = create(:card_grant, event:, amount_cents: 1000, keyword_lock: "\\AHCB-[a-zA-Z]*\\z")
        service = create_service(amount: 1000, stripe_card: card_grant.stripe_card)
        expect(service.run).to be(true)
      end
    end

    context "when category and merchant locked" do
      it "approve with a valid merchant and invalid category" do
        card_grant = create(:card_grant, event:, amount_cents: 1000, merchant_lock: ["1234567890"], category_lock: ["government_licensed_online_casions_online_gambling_us_region_only"])
        service = create_service(amount: 1000, stripe_card: card_grant.stripe_card)
        expect(service.run).to be(true)
      end

      it "approve with a valid category and invalid merchant" do
        card_grant = create(:card_grant, event:, amount_cents: 1000, merchant_lock: ["000737075554888"], category_lock: ["grocery_stores_supermarkets"])
        service = create_service(amount: 1000, stripe_card: card_grant.stripe_card)
        expect(service.run).to be(true)
      end

      it "decline with invalid category and invalid merchant" do
        card_grant = create(:card_grant, event:, amount_cents: 1000, merchant_lock: ["W9JEIROWXKO5PEO"], category_lock: ["wrecking_and_salvage_yards"])
        service = create_service(amount: 1000, stripe_card: card_grant.stripe_card)
        expect(service.run).to be(false)
      end
    end
  end
end
