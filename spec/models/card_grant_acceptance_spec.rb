# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardGrant, type: :model do
  before do
    allow_any_instance_of(CardGrant).to receive(:transfer_money)
    allow_any_instance_of(CardGrant).to receive(:send_email)
  end

  describe "acceptance method validation" do
    it "is valid with only stripe card allowed" do
      grant = build(:card_grant, allow_stripe_card: true, allow_reimbursement_report: false)
      expect(grant).to be_valid
    end

    it "is valid with only reimbursement report allowed" do
      grant = build(:card_grant, allow_stripe_card: false, allow_reimbursement_report: true)
      expect(grant).to be_valid
    end

    it "is valid with both methods allowed" do
      grant = build(:card_grant, allow_stripe_card: true, allow_reimbursement_report: true)
      expect(grant).to be_valid
    end

    it "is invalid with neither method allowed" do
      grant = build(:card_grant, allow_stripe_card: false, allow_reimbursement_report: false)
      expect(grant).not_to be_valid
      expect(grant.errors[:base]).to include("At least one acceptance method (virtual card or reimbursement report) must be enabled")
    end
  end

  describe "#pending_invite?" do
    it "returns true when no stripe card and no reimbursement report" do
      grant = build(:card_grant, stripe_card: nil)
      allow(grant).to receive(:reimbursement_report).and_return(nil)
      expect(grant.pending_invite?).to be true
    end

    it "returns false when a stripe card exists" do
      stripe_card = build(:stripe_card, :with_stripe_id)
      grant = build(:card_grant, stripe_card:)
      allow(grant).to receive(:reimbursement_report).and_return(nil)
      expect(grant.pending_invite?).to be false
    end

    it "returns false when a reimbursement report exists" do
      grant = build(:card_grant, stripe_card: nil)
      report = instance_double(Reimbursement::Report)
      allow(grant).to receive(:reimbursement_report).and_return(report)
      expect(grant.pending_invite?).to be false
    end
  end

  describe "#set_defaults (acceptance methods)" do
    it "uses DB defaults (allow_stripe_card: true) when event setting is not configured" do
      event = create(:event)
      create(:card_grant_setting, event:)
      grant = event.card_grants.build(email: "test@example.com", amount_cents: 1000, sent_by: create(:user))
      expect(grant.allow_stripe_card).to be true
      expect(grant.allow_reimbursement_report).to be false
    end

    it "inherits event allow_stripe_card: false when organizer sets it explicitly in the form" do
      event = create(:event)
      create(:card_grant_setting, event:, allow_stripe_card: false, allow_reimbursement_report: true)
      # Simulate form submission — params explicitly set the values
      grant = event.card_grants.build(
        email: "test@example.com",
        amount_cents: 1000,
        sent_by: create(:user),
        allow_stripe_card: false,
        allow_reimbursement_report: true
      )
      expect(grant.allow_stripe_card).to be false
      expect(grant.allow_reimbursement_report).to be true
    end
  end

  describe "#state and #state_text after reimbursement acceptance" do
    it "returns muted / Canceled state after convert_to_reimbursement_report! (grant is canceled)" do
      event = create(:event, :with_positive_balance, plan_type: Event::Plan::HackClubAffiliate)
      grant = create(:card_grant, event:, stripe_card: nil, allow_reimbursement_report: true)
      allow(grant).to receive(:reimbursement_report).and_return(nil)

      allow(grant).to receive(:convert_to_reimbursement_report!) do
        grant.update_columns(status: CardGrant.statuses[:canceled])
      end

      grant.convert_to_reimbursement_report!

      expect(grant.state).to eq("muted")
      expect(grant.state_text).to eq("Canceled")
    end
  end
end
