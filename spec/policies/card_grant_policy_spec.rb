# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardGrantPolicy, type: :policy do
  before do
    allow_any_instance_of(CardGrant).to receive(:transfer_money)
  end

  describe "#accept_as_reimbursement?" do
    let(:event) { create(:event) }

    it "permits the cardholder when reimbursement acceptance is enabled" do
      card_grant = create(:card_grant, :pending_invite, event:, allow_reimbursement_report: true)
      policy = described_class.new(card_grant.user, card_grant)

      expect(policy.accept_as_reimbursement?).to be(true)
    end

    it "denies the cardholder when reimbursement acceptance is disabled" do
      card_grant = create(:card_grant, :pending_invite, event:, allow_stripe_card: true, allow_reimbursement_report: false)
      policy = described_class.new(card_grant.user, card_grant)

      expect(policy.accept_as_reimbursement?).to be(false)
    end

    it "denies an unrelated user" do
      card_grant = create(:card_grant, :pending_invite, event:, allow_reimbursement_report: true)
      policy = described_class.new(create(:user), card_grant)

      expect(policy.accept_as_reimbursement?).to be(false)
    end

    it "denies once the grant is no longer active" do
      card_grant = create(:card_grant, :pending_invite, event:, allow_reimbursement_report: true)
      card_grant.update_column(:status, :canceled)
      policy = described_class.new(card_grant.user, card_grant)

      expect(policy.accept_as_reimbursement?).to be(false)
    end

    it "denies once a virtual card has been activated" do
      # That's a conversion, gated by `#convert_to_reimbursement_report?`.
      card_grant = create(:card_grant, event:, allow_reimbursement_report: true)
      policy = described_class.new(card_grant.user, card_grant)

      expect(card_grant.stripe_card).to be_present
      expect(policy.accept_as_reimbursement?).to be(false)
    end

    it "denies the cardholder while pre-authorization is outstanding" do
      card_grant = create(:card_grant, :pending_invite, event:, allow_reimbursement_report: true, pre_authorization_required: true)
      policy = described_class.new(card_grant.user, card_grant)

      expect(card_grant.pre_authorization).to be_draft
      expect(policy.accept_as_reimbursement?).to be(false)
    end

    it "permits the cardholder once pre-authorization is approved" do
      card_grant = create(:card_grant, :pending_invite, event:, allow_reimbursement_report: true, pre_authorization_required: true)
      card_grant.pre_authorization.update_column(:aasm_state, "approved")
      policy = described_class.new(card_grant.user, card_grant.reload)

      expect(policy.accept_as_reimbursement?).to be(true)
    end
  end
end
