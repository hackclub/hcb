# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardGrantPolicy, type: :policy do
  before do
    allow_any_instance_of(CardGrant).to receive(:transfer_money)
  end

  describe "#accept_as_reimbursement?" do
    let(:event) { create(:event) }

    it "permits the cardholder when reimbursement acceptance is enabled" do
      card_grant = create(:card_grant, event:, allow_reimbursement_report: true)
      policy = described_class.new(card_grant.user, card_grant)

      expect(policy.accept_as_reimbursement?).to be(true)
    end

    it "denies the cardholder when reimbursement acceptance is disabled" do
      card_grant = create(:card_grant, event:, allow_stripe_card: true, allow_reimbursement_report: false)
      policy = described_class.new(card_grant.user, card_grant)

      expect(policy.accept_as_reimbursement?).to be(false)
    end

    it "denies an unrelated user" do
      card_grant = create(:card_grant, event:, allow_reimbursement_report: true)
      policy = described_class.new(create(:user), card_grant)

      expect(policy.accept_as_reimbursement?).to be(false)
    end

    it "denies once the grant is no longer active" do
      card_grant = create(:card_grant, event:, allow_reimbursement_report: true)
      card_grant.update_column(:status, :canceled)
      policy = described_class.new(card_grant.user, card_grant)

      expect(policy.accept_as_reimbursement?).to be(false)
    end
  end
end
