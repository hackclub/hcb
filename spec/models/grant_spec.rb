# frozen_string_literal: true

require "rails_helper"

RSpec.describe Grant, type: :model do
  describe "creation from a card grant" do
    before { allow_any_instance_of(CardGrant).to receive(:transfer_money) }

    it "creates a pending grant pointing at a fresh (uncarded) invite" do
      card_grant = create(:card_grant, :pending_invite)
      grant = card_grant.grant

      expect(grant).to be_present
      expect(grant).to be_pending
      expect(grant.grantable).to eq(card_grant)
      expect(grant.card_grant).to eq(card_grant)
      expect(grant.reimbursement_report).to be_nil
      expect(grant.event).to eq(card_grant.event)
      expect(grant.user).to eq(card_grant.user)
      expect(grant.sent_by).to eq(card_grant.sent_by)
    end

    it "starts accepted_with_card when the invite already has a card" do
      card_grant = create(:card_grant) # factory attaches a stripe_card

      expect(card_grant.grant).to be_accepted_with_card
    end

    it "enforces one grant per fulfillment via a unique index" do
      card_grant = create(:card_grant, :pending_invite)
      duplicate = Grant.new(event: card_grant.event, user: card_grant.user, sent_by: card_grant.sent_by, grantable: card_grant)

      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "lifecycle sync with the card grant" do
    before { allow_any_instance_of(CardGrant).to receive(:transfer_money) }

    it "cancels the grant when the card grant is canceled" do
      card_grant = create(:card_grant, :pending_invite)

      card_grant.cancel!(card_grant.sent_by)

      expect(card_grant.grant.reload).to be_canceled
    end

    it "expires the grant when the card grant expires" do
      allow(User).to receive(:system_user).and_return(create(:user, email: User::SYSTEM_USER_EMAIL))
      card_grant = create(:card_grant, :pending_invite)

      card_grant.expire!

      expect(card_grant.grant.reload).to be_expired
    end
  end

  describe "conversion to a reimbursement report" do
    let(:event) { create(:event, :with_positive_balance, plan_type: Event::Plan::HackClubAffiliate) }

    before { create(:card_grant_setting, event:) }

    it "repoints the grant to the report and marks it accepted_with_reimbursement" do
      card_grant = create(:card_grant, :pending_invite, event:, amount_cents: 10_00, allow_reimbursement_report: true)
      grant = card_grant.grant
      expect(grant).to be_pending

      report = card_grant.convert_to_reimbursement_report!(accepted_by: card_grant.user)

      grant.reload
      expect(grant.grantable).to eq(report)
      expect(grant.reimbursement_report).to eq(report)
      expect(grant.card_grant).to be_nil
      expect(grant).to be_accepted_with_reimbursement
      expect(report.grant).to eq(grant)
    end
  end

  describe "AASM guards" do
    before { allow_any_instance_of(CardGrant).to receive(:transfer_money) }

    it "refuses to cancel a grant already accepted as a reimbursement" do
      grant = create(:card_grant, :pending_invite).grant
      grant.update_column(:aasm_state, "accepted_with_reimbursement")

      expect(grant.reload.may_mark_canceled?).to be(false)
      expect { grant.mark_canceled! }.to raise_error(AASM::InvalidTransition)
    end

    it "refuses to re-accept a canceled grant" do
      grant = create(:card_grant, :pending_invite).grant
      grant.mark_canceled!

      expect(grant.may_mark_accepted_with_card?).to be(false)
      expect(grant.may_mark_accepted_with_reimbursement?).to be(false)
    end
  end
end
