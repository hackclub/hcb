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

  describe "acceptance methods" do
    before do
      allow_any_instance_of(CardGrant).to receive(:transfer_money)
    end

    it "is invalid when neither acceptance method is enabled" do
      event = create(:event)
      card_grant = build(:card_grant, event:, allow_stripe_card: false, allow_reimbursement_report: false)

      expect(card_grant).to be_invalid
      expect(card_grant.errors[:base]).to include(
        "At least one acceptance method (virtual card or reimbursement report) must be enabled"
      )
    end

    it "is valid when only reimbursement acceptance is enabled" do
      event = create(:event)
      card_grant = build(:card_grant, event:, allow_stripe_card: false, allow_reimbursement_report: true)

      expect(card_grant).to be_valid
    end

    it "inherits acceptance-method defaults from the event's card grant setting" do
      event = create(:event)
      create(:card_grant_setting, event:, allow_stripe_card: false, allow_reimbursement_report: true)

      card_grant = create(:card_grant, event:)

      expect(card_grant.allow_stripe_card).to eq(false)
      expect(card_grant.allow_reimbursement_report).to eq(true)
    end

    it "keeps an explicitly set acceptance method over the event default" do
      event = create(:event)
      create(:card_grant_setting, event:, allow_stripe_card: true, allow_reimbursement_report: false)

      card_grant = create(:card_grant, event:, allow_reimbursement_report: true)

      expect(card_grant.allow_reimbursement_report).to eq(true)
    end
  end

  describe "#state / #state_text for reimbursement-accepted grants" do
    before do
      allow_any_instance_of(CardGrant).to receive(:transfer_money)
    end

    it "reports as active once a reimbursement report is attached, even though the grant is canceled" do
      event = create(:event)
      card_grant = create(:card_grant, event:, allow_reimbursement_report: true)
      create(:reimbursement_report, event:, user: card_grant.user, card_grant:)
      card_grant.update_column(:status, :canceled)

      expect(card_grant.reload.canceled?).to be(true)
      expect(card_grant.state).to eq("success")
      expect(card_grant.state_text).to eq("Active")
    end
  end
end
