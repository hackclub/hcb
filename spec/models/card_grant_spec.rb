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

  describe "#state_text" do
    let(:system_user) { User.find_or_create_by!(email: User::SYSTEM_USER_EMAIL) }

    before do
      allow_any_instance_of(CardGrant).to receive(:transfer_money)
      allow(User).to receive(:system_user).and_return(system_user)
    end

    context "when card is frozen by the system user (one time use)" do
      it "returns the one-time-use frozen message" do
        card_grant = create(:card_grant)
        card_grant.one_time_use = true
        card_grant.stripe_card.update!(stripe_status: "inactive", last_frozen_by: system_user)
        allow(card_grant.stripe_card).to receive(:frozen?).and_return(true)

        expect(card_grant.state_text).to eq("Frozen")
        expect(card_grant.frozen_by_one_time_use?).to eq(true)
      end
    end

    context "when card is frozen by a non-system user" do
      it "returns 'Frozen'" do
        card_grant = create(:card_grant)
        other_user = create(:user)
        card_grant.stripe_card.update!(stripe_status: "inactive", last_frozen_by: other_user)
        allow(card_grant.stripe_card).to receive(:frozen?).and_return(true)

        expect(card_grant.state_text).to eq("Frozen")
        expect(card_grant.frozen_by_one_time_use?).to eq(false)
      end
    end

    context "when card is frozen with no last_frozen_by" do
      it "returns 'Frozen'" do
        card_grant = create(:card_grant)
        card_grant.stripe_card.update!(stripe_status: "inactive", last_frozen_by: nil)
        allow(card_grant.stripe_card).to receive(:frozen?).and_return(true)

        expect(card_grant.state_text).to eq("Frozen")
        expect(card_grant.frozen_by_one_time_use?).to eq(false)
      end
    end

    context "when card is inactive (never activated) by system user" do
      it "returns the one-time-use frozen message" do
        card_grant = create(:card_grant)
        card_grant.stripe_card.update!(stripe_status: "inactive", last_frozen_by: system_user)
        card_grant.one_time_use = false
        allow(card_grant.stripe_card).to receive(:frozen?).and_return(false)
        allow(card_grant.stripe_card).to receive(:inactive?).and_return(true)

        expect(card_grant.state_text).to eq("Frozen")
        expect(card_grant.frozen_by_one_time_use?).to eq(false)
      end
    end
  end
end
