# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardGrant, type: :model do
  describe "state scopes" do
    before do
      allow_any_instance_of(CardGrant).to receive(:transfer_money)
    end

    let(:event) { create(:event) }
    let!(:not_activated) { create(:card_grant, event:, stripe_card: nil) }
    let!(:accepted) { create(:card_grant, event:) }
    let!(:frozen) { create(:card_grant, event:, stripe_card: create(:stripe_card, :with_stripe_id, event:, stripe_status: "inactive", initially_activated: true)) }
    let!(:expired) { create(:card_grant, event:).tap { |grant| grant.update!(status: :expired) } }
    let!(:returned) { create(:card_grant, event:).tap { |grant| grant.update!(status: :canceled) } }
    let!(:converted) do
      create(:card_grant, event:).tap do |grant|
        grant.update!(status: :canceled)
        create(:reimbursement_report, event:, user: grant.user, card_grant: grant)
      end
    end

    it "sorts each grant status into one state" do
      expect(event.card_grants.not_activated).to contain_exactly(not_activated)
      expect(event.card_grants.accepted).to contain_exactly(accepted)
      expect(event.card_grants.frozen).to contain_exactly(frozen)
      expect(event.card_grants.expired).to contain_exactly(expired)
      expect(event.card_grants.returned).to contain_exactly(returned)
      expect(event.card_grants.converted_to_reimbursement).to contain_exactly(converted)
    end

    describe ".filter_by_state" do
      it "filters to the state" do
        expect(event.card_grants.filter_by_state("not_activated")).to contain_exactly(not_activated)
      end

      it "ignores unknown states" do
        expect(event.card_grants.filter_by_state("nonsense")).to contain_exactly(not_activated, accepted, frozen, expired, returned, converted)
        expect(event.card_grants.filter_by_state(nil)).to contain_exactly(not_activated, accepted, frozen, expired, returned, converted)
      end
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
