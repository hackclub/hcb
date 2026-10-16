# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardGrant, type: :model do
  describe "ledger association" do
    # CardGrant has an after_create :transfer_money callback that triggers
    # DisbursementService::Create, which requires the source event to have
    # sufficient balance and creates actual disbursement records. We stub
    # this callback to test ledger creation in isolation without needing
    # to set up a full funded event with transactions.
    before do
      allow_any_instance_of(CardGrant).to receive(:transfer_money)
    end

    it "automatically creates a primary ledger after creation" do
      card_grant = create(:card_grant)

      expect(card_grant.ledger).to be_present
      expect(card_grant.ledger.primary?).to be true
      expect(card_grant.ledger.card_grant).to eq(card_grant)
    end

    it "has a primary ledger association" do
      card_grant = create(:card_grant)

      expect(card_grant).to respond_to(:ledger)
      expect(card_grant.ledger).to be_a(Ledger)
    end
  end

  describe "restriction conflicts with the setting" do
    before do
      allow_any_instance_of(CardGrant).to receive(:transfer_money)
    end

    let(:card_grant) { create(:card_grant) }

    it "rejects allowing a merchant the setting blocks" do
      card_grant.setting.update!(banned_merchants: ["merchant_a"])
      card_grant.merchant_lock = ["merchant_a"]

      expect(card_grant).not_to be_valid
      expect(card_grant.errors[:base]).to include("Merchant merchant_a cannot be both allowed and blocked")
    end

    it "rejects blocking a category the setting allows" do
      card_grant.setting.update!(category_lock: ["food"])
      card_grant.banned_categories = ["food"]

      expect(card_grant).not_to be_valid
      expect(card_grant.errors[:base]).to include("Category food cannot be both allowed and blocked")
    end

    it "still saves an existing grant after the setting later blocks one of its merchants" do
      card_grant = create(:card_grant, merchant_lock: ["merchant_a"])
      card_grant.setting.update!(banned_merchants: ["merchant_a"])
      card_grant.reload

      expect(card_grant.update(purpose: "Snacks")).to be true

      card_grant.merchant_lock += ["merchant_b"]
      expect(card_grant).not_to be_valid
    end
  end
end
