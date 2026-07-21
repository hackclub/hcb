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

  describe "expiration_at validation" do
    before do
      allow_any_instance_of(CardGrant).to receive(:transfer_money)
    end

    it "accepts an expiration date within 3 years" do
      card_grant = create(:card_grant, expiration_at: 2.years.from_now.to_date)
      expect(card_grant).to be_valid
    end

    it "accepts an expiration date exactly at the boundary" do
      card_grant = create(:card_grant, expiration_at: 3.years.from_now.to_date)
      expect(card_grant).to be_valid
    end

    it "rejects an expiration date more than 3 years in the future" do
      card_grant = create(:card_grant, expiration_at: Date.current)
      card_grant.expiration_at = 4.years.from_now.to_date
      expect(card_grant).not_to be_valid
      expect(card_grant.errors[:expiration_at]).to be_present
    end

    it "uses a default expiration_at when not provided" do
      card_grant = create(:card_grant)
      expect(card_grant.expiration_at).to be_present
    end
  end
end
