# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::FreezeLockedUsersCardsTask do
  let(:locked_user) { create(:user, locked_at: 1.day.ago) }
  let(:unlocked_user) { create(:user) }

  it "only collects locked users" do
    locked_user
    unlocked_user

    expect(described_class.collection).to contain_exactly(locked_user)
  end

  it "freezes a locked user's active cards" do
    card = create(:stripe_card, :with_stripe_id, initially_activated: true, stripe_cardholder: create(:stripe_cardholder, user: locked_user))
    allow(User).to receive(:system_user).and_return(create(:user, email: User::SYSTEM_USER_EMAIL))
    expect(StripeService::Issuing::Card).to receive(:update).with(card.stripe_id, status: :inactive)
    allow(Stripe::Issuing::Card).to receive(:retrieve).with(id: card.stripe_id).and_return(
      Stripe::Issuing::Card.construct_from(id: card.stripe_id, status: "inactive", brand: "Visa", exp_month: 2, exp_year: 2030, last4: card.last4, type: "virtual", shipping: nil, spending_controls: { spending_limits: [] })
    )

    described_class.process(locked_user)

    expect(card.reload).to be_frozen
  end

  it "skips a user who is no longer locked" do
    create(:stripe_card, :with_stripe_id, stripe_cardholder: create(:stripe_cardholder, user: unlocked_user))
    expect(StripeService::Issuing::Card).not_to receive(:update)

    described_class.process(unlocked_user)
  end
end
