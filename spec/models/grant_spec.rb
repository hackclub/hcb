# frozen_string_literal: true

require "rails_helper"

RSpec.describe Grant, type: :model do
  describe "creation from a card grant" do
    before { allow_any_instance_of(CardGrant).to receive(:transfer_money) }

    it "is created automatically, exactly once, pointing at the card grant" do
      card_grant = create(:card_grant, :pending_invite)

      expect(card_grant.grant).to be_present
      expect(Grant.where(grantable: card_grant).count).to eq(1)
      expect(card_grant.grant).to have_attributes(
        event: card_grant.event,
        user: card_grant.user,
        sent_by: card_grant.sent_by
      )
    end

    it "refuses a second grant for the same fulfillment" do
      card_grant = create(:card_grant, :pending_invite)

      expect do
        Grant.create!(grantable: card_grant, event: card_grant.event, user: card_grant.user, sent_by: card_grant.sent_by)
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "rejects a grantable that is neither a card grant nor a reimbursement report" do
      event = create(:event)
      grant = Grant.new(grantable: event, event:, user: create(:user), sent_by: create(:user))

      expect(grant).to be_invalid
      expect(grant.errors[:grantable_type]).to be_present
    end

    it "requires a grantable" do
      grant = Grant.new(event: create(:event), user: create(:user), sent_by: create(:user))

      expect(grant).to be_invalid
      expect(grant.errors[:grantable]).to be_present
    end
  end

  describe "#status" do
    before { allow_any_instance_of(CardGrant).to receive(:transfer_money) }

    it "is pending before the recipient accepts" do
      grant = create(:card_grant, :pending_invite).grant

      expect(grant.status).to eq("pending")
      expect(grant).to be_pending
      expect(grant).not_to be_accepted
    end

    it "is accepted_with_card once a virtual card exists" do
      grant = create(:card_grant).grant

      expect(grant.status).to eq("accepted_with_card")
      expect(grant).to be_accepted_with_card
      expect(grant).to be_accepted
    end

    it "reports canceled even when a card had already been activated" do
      card_grant = create(:card_grant)
      card_grant.update_column(:status, CardGrant.statuses[:canceled])

      expect(card_grant.grant.status).to eq("canceled")
      expect(card_grant.grant).not_to be_accepted_with_card
    end

    it "reports expired" do
      card_grant = create(:card_grant, :pending_invite)
      card_grant.update_column(:status, CardGrant.statuses[:expired])

      expect(card_grant.grant.status).to eq("expired")
    end
  end

  describe "acceptance as a reimbursement" do
    let(:event) { create(:event, :with_positive_balance, plan_type: Event::Plan::HackClubAffiliate) }

    before { create(:card_grant_setting, event:) }

    it "moves the single grant onto the report and derives the reimbursement status" do
      card_grant = create(:card_grant, :pending_invite, event:, amount_cents: 10_00, allow_reimbursement_report: true)
      grant = card_grant.grant

      report = card_grant.convert_to_reimbursement_report!(accepted_by: card_grant.user)

      expect(grant.reload.grantable).to eq(report)
      expect(grant.status).to eq("accepted_with_reimbursement")
      expect(grant).to be_accepted
      expect(report.grant).to eq(grant)
      # the original card grant no longer owns a grant through its own polymorphic link,
      # but the grant still resolves back to it and is never duplicated
      expect(card_grant.reload.grant).to be_nil
      expect(grant.card_grant).to eq(card_grant)
      expect(Grant.count).to eq(1)
    end

    it "keeps delegating invitation data through the originating card grant after conversion" do
      card_grant = create(:card_grant, :pending_invite, event:, amount_cents: 10_00, purpose: "Pizza", allow_reimbursement_report: true)
      grant = card_grant.grant

      card_grant.convert_to_reimbursement_report!(accepted_by: card_grant.user)

      expect(grant.reload.purpose).to eq("Pizza")
      expect(grant.amount_cents).to eq(10_00)
      expect(grant.email).to eq(card_grant.email)
      expect(grant.reimbursement_report).to eq(card_grant.reimbursement_report)
    end
  end

  describe "delegation and settings inheritance" do
    before { allow_any_instance_of(CardGrant).to receive(:transfer_money) }

    it "delegates invitation attributes to the card grant" do
      card_grant = create(:card_grant, :pending_invite, purpose: "Soldering iron", instructions: "Buy from Adafruit")
      grant = card_grant.grant

      expect(grant.purpose).to eq("Soldering iron")
      expect(grant.instructions).to eq("Buy from Adafruit")
      expect(grant.amount).to eq(card_grant.amount)
    end

    it "resolves effective acceptance methods from the card grant, inheriting the event setting" do
      event = create(:event)
      create(:card_grant_setting, event:, allow_stripe_card: false, allow_reimbursement_report: true)
      grant = create(:card_grant, :pending_invite, event:).grant

      expect(grant.effective_allow_stripe_card).to eq(false)
      expect(grant.effective_allow_reimbursement_report).to eq(true)
    end
  end

  describe "associations" do
    before { allow_any_instance_of(CardGrant).to receive(:transfer_money) }

    it "is listed under its event and recipient" do
      card_grant = create(:card_grant, :pending_invite)
      grant = card_grant.grant

      expect(card_grant.event.grants).to include(grant)
      expect(card_grant.user.grants).to include(grant)
    end
  end
end
