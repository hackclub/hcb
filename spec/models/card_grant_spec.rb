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

    describe "#at_least_one_acceptance_method" do
      it "is invalid when both acceptance methods are disabled" do
        card_grant = build(:card_grant, allow_stripe_card: false, allow_reimbursement_report: false)

        expect(card_grant).to be_invalid
        expect(card_grant.errors[:base]).to include("At least one acceptance method (virtual card or reimbursement report) must be enabled")
      end

      it "is valid when at least one acceptance method is enabled" do
        card_grant = build(:card_grant, allow_stripe_card: true, allow_reimbursement_report: false)

        card_grant.valid?

        expect(card_grant.errors[:base]).to be_empty
      end
    end

    describe "#apply_acceptance_method_defaults" do
      it "inherits the acceptance methods from the event setting when left unspecified" do
        event = create(:event)
        create(:card_grant_setting, event:, allow_stripe_card: false, allow_reimbursement_report: true)
        card_grant = build(:card_grant, event:, allow_stripe_card: nil, allow_reimbursement_report: nil)

        card_grant.valid?

        expect(card_grant.allow_stripe_card).to be false
        expect(card_grant.allow_reimbursement_report).to be true
      end

      it "does not override explicitly provided values" do
        event = create(:event)
        create(:card_grant_setting, event:, allow_stripe_card: false, allow_reimbursement_report: true)
        card_grant = build(:card_grant, event:, allow_stripe_card: true, allow_reimbursement_report: false)

        card_grant.valid?

        expect(card_grant.allow_stripe_card).to be true
        expect(card_grant.allow_reimbursement_report).to be false
      end
    end
  end

  describe "state" do
    before do
      allow_any_instance_of(CardGrant).to receive(:transfer_money)
    end

    it "reports as active once accepted as a reimbursement, even though it is canceled" do
      card_grant = build(:card_grant)
      allow(card_grant).to receive(:reimbursement_report).and_return(build(:reimbursement_report))
      allow(card_grant).to receive(:canceled?).and_return(true)

      expect(card_grant.state).to eq("success")
      expect(card_grant.state_text).to eq("Active")
    end

    it "is not a pending invite once a reimbursement report exists" do
      card_grant = build(:card_grant, stripe_card: nil)
      allow(card_grant).to receive(:reimbursement_report).and_return(build(:reimbursement_report))

      expect(card_grant.pending_invite?).to be false
    end
  end
end
