# frozen_string_literal: true

require "rails_helper"

RSpec.describe StripeCardPolicy, type: :policy do
  describe "a cardholder locked out of the organization for not enabling two-factor authentication" do
    let(:event) { create(:event) }
    let(:cardholder) { create(:organizer_position, event:, role: :member).user }
    let(:card) { create(:stripe_card, :with_stripe_id, event:, stripe_cardholder: create(:stripe_cardholder, user: cardholder)) }

    subject(:policy) { described_class.new(cardholder, card) }

    before { require_two_factor_authentication!(event, at: 8.days.ago) }

    it "can still freeze and cancel their own card" do
      expect(policy.freeze?).to eq(true)
      expect(policy.cancel?).to eq(true)
    end

    it "can no longer see the card number, edit, or activate the card" do
      expect(policy.ephemeral_keys?).to eq(false)
      expect(policy.edit?).to eq(false)
      expect(policy.update?).to eq(false)
      expect(policy.activate?).to eq(false)
      expect(policy.show?).to be_falsey
    end

    it "doesn't extend to someone else's card" do
      other_card = create(:stripe_card, :with_stripe_id, event:, stripe_cardholder: create(:stripe_cardholder, user: create(:organizer_position, event:).user))

      expect(described_class.new(cardholder, other_card).freeze?).to eq(false)
      expect(described_class.new(cardholder, other_card).cancel?).to eq(false)
    end
  end
end
