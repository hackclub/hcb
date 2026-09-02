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

    it "is invalid when neither acceptance method is enabled explicitly" do
      event = create(:event)
      card_grant = build(:card_grant, event:, allow_stripe_card: false, allow_reimbursement_report: false)

      expect(card_grant).to be_invalid
      expect(card_grant.errors[:base]).to include(
        "At least one acceptance method (virtual card or reimbursement report) must be enabled"
      )
    end

    it "is invalid when both methods are disabled via inheritance from the setting" do
      event = create(:event)
      create(:card_grant_setting, event:, allow_stripe_card: true, allow_reimbursement_report: false)
      # Only stripe card is disabled per-grant; reimbursement inherits the setting's false.
      card_grant = build(:card_grant, event:, allow_stripe_card: false)

      expect(card_grant).to be_invalid
    end

    it "is valid when only reimbursement acceptance is enabled" do
      event = create(:event)
      card_grant = build(:card_grant, event:, allow_stripe_card: false, allow_reimbursement_report: true)

      expect(card_grant).to be_valid
    end

    it "leaves unset methods NULL and resolves them from the event setting (inherit-live)" do
      event = create(:event)
      create(:card_grant_setting, event:, allow_stripe_card: false, allow_reimbursement_report: true)

      card_grant = create(:card_grant, event:)

      expect(card_grant.allow_stripe_card).to be_nil
      expect(card_grant.allow_reimbursement_report).to be_nil
      expect(card_grant.effective_allow_stripe_card).to eq(false)
      expect(card_grant.effective_allow_reimbursement_report).to eq(true)
    end

    it "keeps an explicitly set acceptance method over the event default" do
      event = create(:event)
      create(:card_grant_setting, event:, allow_stripe_card: true, allow_reimbursement_report: false)

      card_grant = create(:card_grant, event:, allow_reimbursement_report: true)

      expect(card_grant.allow_reimbursement_report).to eq(true)
      expect(card_grant.effective_allow_reimbursement_report).to eq(true)
      expect(card_grant.effective_allow_stripe_card).to eq(true) # still inherited
    end
  end

  describe "#convert_to_reimbursement_report!" do
    let(:event) { create(:event, :with_positive_balance, plan_type: Event::Plan::HackClubAffiliate) }

    before { create(:card_grant_setting, event:) }

    def pending_grant(**overrides)
      create(:card_grant, :pending_invite, event:, amount_cents: 10_00, allow_reimbursement_report: true, **overrides)
    end

    it "transitions into the converted state, returns funds, and opens a report" do
      grant = pending_grant

      expect { grant.convert_to_reimbursement_report!(accepted_by: grant.user) }
        .to change(Reimbursement::Report, :count).by(1)

      expect(grant.reload).to be_converted_to_reimbursement
      expect(grant).not_to be_canceled
      expect(grant.balance.cents).to eq(0)
    end

    it "attributes the returned funds to the accepting user rather than the system user" do
      grant = pending_grant

      grant.convert_to_reimbursement_report!(accepted_by: grant.user)

      expect(grant.withdrawal_disbursements.last.requested_by).to eq(grant.user)
    end

    it "guards against a double conversion so retries can't spawn a second report" do
      grant = pending_grant
      grant.convert_to_reimbursement_report!(accepted_by: grant.user)

      expect { grant.convert_to_reimbursement_report!(accepted_by: grant.user) }
        .to raise_error(ArgumentError, /already/)
      expect(Reimbursement::Report.where(card_grant: grant).count).to eq(1)
    end

    it "refuses to convert a grant with no remaining balance" do
      grant = pending_grant
      grant.zero!(requested_by: grant.user)

      expect { grant.convert_to_reimbursement_report!(accepted_by: grant.user) }
        .to raise_error(ArgumentError, /non-zero balance/)
    end
  end

  describe "#state / #state_text" do
    before do
      allow_any_instance_of(CardGrant).to receive(:transfer_money)
    end

    it "reports converted grants as success via the explicit AASM state" do
      event = create(:event)
      card_grant = create(:card_grant, event:, allow_reimbursement_report: true)
      create(:reimbursement_report, event:, user: card_grant.user, card_grant:)
      card_grant.update_column(:status, CardGrant.statuses[:converted_to_reimbursement])

      card_grant.reload
      expect(card_grant).to be_converted_to_reimbursement
      expect(card_grant).not_to be_canceled
      expect(card_grant.state).to eq("success")
      expect(card_grant.state_text).to eq("Converted to reimbursement")
    end

    it "does not read a plain canceled grant as converted" do
      event = create(:event)
      card_grant = create(:card_grant, :pending_invite, event:)
      card_grant.update_column(:status, CardGrant.statuses[:canceled])

      expect(card_grant.reload).not_to be_converted_to_reimbursement
      expect(card_grant.state).to eq("muted")
      expect(card_grant.state_text).to eq("Canceled")
    end
  end
end
