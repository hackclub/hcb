# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardGrant, type: :model do
  describe "expiration" do
    before do
      allow_any_instance_of(CardGrant).to receive(:transfer_money)
    end

    it "expires 90 days after creation under default settings" do
      card_grant = create(:card_grant)

      expect(card_grant.expiration_at).to eq(90.days.from_now.to_date)
    end

    it "honours a longer expiration preference on the organization's settings" do
      event = create(:event)
      create(:card_grant_setting, event:, expiration_preference: "1 year")

      card_grant = create(:card_grant, event:)

      expect(card_grant.expiration_at).to eq(365.days.from_now.to_date)
    end
  end

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
end
