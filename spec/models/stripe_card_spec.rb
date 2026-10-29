# frozen_string_literal: true

require "rails_helper"

RSpec.describe StripeCard, type: :model do
  context "without stripe id" do
    let(:stripe_card) { create(:stripe_card) }

    it "is valid" do
      expect(stripe_card).to be_valid
    end
  end

  context "with stripe id" do
    let(:stripe_card) { create(:stripe_card, :with_stripe_id) }

    it "is valid" do
      expect(stripe_card).to be_valid
    end
  end

  describe "#freeze!" do
    let(:stripe_card) { create(:stripe_card, :with_stripe_id, initially_activated: true) }
    let(:user) { create(:user) }

    before do
      allow(User).to receive(:system_user).and_return(create(:user, email: User::SYSTEM_USER_EMAIL))
      allow(StripeService::Issuing::Card).to receive(:update)
      allow(stripe_card).to receive(:sync_from_stripe!) { stripe_card.stripe_status = "inactive" }
    end

    it "records who froze the card" do
      stripe_card.freeze!(frozen_by: user)

      expect(stripe_card.reload.last_frozen_by).to eq(user)
    end

    it "does not overwrite who froze an already frozen card" do
      stripe_card.update!(stripe_status: "inactive", last_frozen_by: User.system_user)

      stripe_card.freeze!(frozen_by: user)

      expect(StripeService::Issuing::Card).not_to have_received(:update)
      expect(stripe_card.reload.last_frozen_by).to eq(User.system_user)
    end
  end

  describe "#defrost!" do
    it "disables one time use on the card grant so it is not immediately re-frozen" do
      allow_any_instance_of(CardGrant).to receive(:transfer_money)
      card_grant = create(:card_grant, one_time_use: true)
      stripe_card = card_grant.stripe_card
      stripe_card.update!(initially_activated: true, stripe_status: "inactive")
      allow(StripeService::Issuing::Card).to receive(:update)
      allow(stripe_card).to receive(:sync_from_stripe!) { stripe_card.stripe_status = "active" }

      stripe_card.defrost!

      expect(card_grant.reload.one_time_use).to be(false)
    end
  end
end
