# frozen_string_literal: true

require "rails_helper"

RSpec.describe StripeAuthorizationService::Webhook::HandleIssuingAuthorizationRequest, type: :model do
  include ActionMailer::TestHelper

  let(:event) { create(:event) }
  let(:stripe_card) { create(:stripe_card, :with_stripe_id, event:) }
  let(:stripe_authorization) { build(:stripe_authorization, card: { id: stripe_card.stripe_id }) }
  let(:service) do
    StripeAuthorizationService::Webhook::HandleIssuingAuthorizationRequest.new(
      stripe_event: { data: { object: stripe_authorization, } }
    )
  end

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

  context "forbidden merchants" do
    let(:stripe_authorization) do
      build(
        :stripe_authorization,
        :gambling,
        card: { id: stripe_card.stripe_id }
      )
    end

    it "declines and notifies ops" do
      sent_emails = capture_emails do
        expect(service.run).to be(false)
      end

      expect(service.declined_reason).to eq("merchant_not_allowed")

      ops_email =
        sent_emails
        .filter { |mail| mail.recipients.include?(ApplicationMailer::OPERATIONS_EMAIL) }
        .sole

      expect(ops_email.subject).to eq("#{event.name}: Stripe card authorization blocked")
    end
  end

  context "card grants" do
    let(:event) { create(:event, :card_grant_event) }
    before(:example) { create(:canonical_pending_transaction, amount_cents: 10000, event:, fronted: true ) }

    def create_service(stripe_card: card_grant.stripe_card, amount: 1000)
      StripeAuthorizationService::Webhook::HandleIssuingAuthorizationRequest.new(stripe_event: { data: { object: build(:stripe_authorization, card: { id: stripe_card.stripe_id }, pending_request: { amount: }) } })
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
        expect(service.declined_reason).to eq("merchant_not_allowed")
      end
    end

    context "when restricted by merchant" do
      it "approve with a valid merchant" do
        card_grant = create(:card_grant, event:, amount_cents: 1000, banned_merchants: ["0987654321"])
        service = create_service(amount: 1000, stripe_card: card_grant.stripe_card)
        expect(service.run).to be(true)
      end

      it "decline with a banned merchant" do
        card_grant = create(:card_grant, event:, amount_cents: 1000, banned_merchants: ["1234567890"])
        service = create_service(amount: 1000, stripe_card: card_grant.stripe_card)
        expect(service.run).to be(false)
        expect(service.declined_reason).to eq("merchant_not_allowed")
      end
    end

    context "when restricted by category" do
      it "approve with a valid category" do
        card_grant = create(:card_grant, event:, amount_cents: 1000, banned_categories: ["fast_food_restaurants"])
        service = create_service(amount: 1000, stripe_card: card_grant.stripe_card)
        expect(service.run).to be(true)
      end

      it "decline with a banned category" do
        card_grant = create(:card_grant, event:, amount_cents: 1000, banned_categories: ["grocery_stores_supermarkets"])
        service = create_service(amount: 1000, stripe_card: card_grant.stripe_card)
        expect(service.run).to be(false)
        expect(service.declined_reason).to eq("merchant_not_allowed")
      end
    end

    context "when merchant locked and restricted by category" do
      it "approve with a valid merchant and valid category" do
        card_grant = create(:card_grant, event:, amount_cents: 1000, merchant_lock: ["1234567890"], banned_categories: ["fast_food_restaurants"])
        service = create_service(amount: 1000, stripe_card: card_grant.stripe_card)
        expect(service.run).to be(true)
      end

      it "decline with a valid merchant and invalid category" do
        card_grant = create(:card_grant, event:, amount_cents: 1000, merchant_lock: ["1234567890"], banned_categories: ["grocery_stores_supermarkets"])
        service = create_service(amount: 1000, stripe_card: card_grant.stripe_card)
        expect(service.run).to be(false)
        expect(service.declined_reason).to eq("merchant_not_allowed")
      end

      it "decline with an invalid merchant and valid category" do
        card_grant = create(:card_grant, event:, amount_cents: 1000, merchant_lock: ["0987654321"], banned_categories: ["fast_food_restaurants"])
        service = create_service(amount: 1000, stripe_card: card_grant.stripe_card)
        expect(service.run).to be(false)
        expect(service.declined_reason).to eq("merchant_not_allowed")
      end
    end
  end

  context "locked user" do
    it "declines with user_locked reason" do
      create(:canonical_pending_transaction, amount_cents: 1000, event:, fronted: true)
      stripe_card.user.update!(locked_at: Time.now)

      expect(service.run).to be(false)
      expect(service.declined_reason).to eq("user_locked")
    end
  end

  context "withdrawals" do
    let(:stripe_authorization) do
      build(
        :stripe_authorization,
        :cash_withdrawal,
        card: { id: stripe_card.stripe_id }
      )
    end

    it "declines by default" do
      create(:canonical_pending_transaction, amount_cents: 1000, event:, fronted: true)

      expect(service.run).to be(false)
      expect(service.declined_reason).to eq("cash_withdrawals_not_allowed")
    end

    it "approves if allowed" do
      create(:canonical_pending_transaction, amount_cents: 1000, event:, fronted: true)
      stripe_card.update!(cash_withdrawal_enabled: true)

      expect(service.run).to be(true)
    end

    context "with amount > $500" do
      let(:stripe_authorization) do
        build(
          :stripe_authorization,
          :cash_withdrawal,
          card: { id: stripe_card.stripe_id },
          pending_amount: 500_01,
        )
      end

      it "declines" do
        create(:canonical_pending_transaction, amount_cents: 1000_00, event:, fronted: true)
        stripe_card.update!(cash_withdrawal_enabled: true)

        expect(service.run).to be(false)
        expect(service.declined_reason).to eq("exceeds_approval_amount_limit")
      end
    end
  end
end
