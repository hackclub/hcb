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

  describe "keyword lock validation" do
    it "rejects an invalid regular expression" do
      card_grant = build(:card_grant, event: create(:event), keyword_lock: "[unclosed")

      expect(card_grant).not_to be_valid
      expect(card_grant.errors[:keyword_lock]).to include("is not a valid regular expression")
    end

    it "allows a valid regular expression" do
      card_grant = build(:card_grant, event: create(:event), keyword_lock: "\\AApple")
      card_grant.validate

      expect(card_grant.errors[:keyword_lock]).to be_empty
    end

    it "doesn't validate the event's fallback setting" do
      event = create(:event)
      create(:card_grant_setting, event:, keyword_lock: "[unclosed")
      card_grant = build(:card_grant, event:)
      card_grant.validate

      expect(card_grant.keyword_lock).to eq("[unclosed")

      expect(card_grant.errors[:keyword_lock]).to be_empty
    end
  end
end
