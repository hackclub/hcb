# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardGrant::FreezeOneTimeUseJob do
  let(:system_user) { create(:user, email: User::SYSTEM_USER_EMAIL) }
  let(:card_grant) { create(:card_grant, event: create(:event, :with_positive_balance), one_time_use: true) }
  let(:card) { card_grant.stripe_card }

  before do
    allow(User).to receive(:system_user).and_return(system_user)
    allow(Stripe::Issuing::Card).to receive(:update)
    allow(Stripe::Issuing::Card).to receive(:retrieve).and_return(
      Stripe::Issuing::Card.construct_from(
        id: card.stripe_id,
        status: "inactive",
        type: "virtual",
        brand: "Visa",
        exp_month: 2,
        exp_year: 2030,
        last4: "9876",
        spending_controls: { spending_limits: [] }
      )
    )
    card.update!(stripe_status: "active", initially_activated: true)
  end

  def force_capture(stripe_card = card, **stripe_transaction)
    rst = create(:raw_stripe_transaction, stripe_card:)
    rst.update_columns(stripe_transaction: rst.stripe_transaction.merge(stripe_transaction.stringify_keys)) if stripe_transaction.any?
    rst
  end

  def perform(rst)
    described_class.perform_now(raw_stripe_transaction_id: rst.id)
  end

  it "is enqueued when a force capture is imported" do
    expect { force_capture }.to have_enqueued_job(described_class)
  end

  it "is not enqueued for a capture with an authorization" do
    expect { create(:raw_stripe_transaction, stripe_card: card, stripe_authorization_id: "iauth_123") }.not_to have_enqueued_job(described_class)
  end

  it "is not enqueued for a refund" do
    rst = build(:raw_stripe_transaction, stripe_card: card)
    rst.stripe_transaction["type"] = "refund"

    expect { rst.save! }.not_to have_enqueued_job(described_class)
  end

  it "freezes a one-time-use grant card as the system user" do
    expect(Stripe::Issuing::Card).to receive(:update).with(card.stripe_id, status: :inactive)

    perform(force_capture)

    expect(card.reload).to be_frozen
    expect(card.last_frozen_by).to eq(system_user)
    expect(card_grant.reload.one_time_use).to eq(true)
  end

  it "does nothing when the grant is not one-time-use" do
    card_grant.update!(one_time_use: false)

    perform(force_capture)

    expect(Stripe::Issuing::Card).not_to have_received(:update)
  end

  it "does nothing for a grant that is no longer active" do
    card_grant.update!(status: "canceled")

    perform(force_capture)

    expect(Stripe::Issuing::Card).not_to have_received(:update)
  end

  it "keeps an organizer's freeze" do
    organizer = create(:user)
    card.update!(stripe_status: "inactive", last_frozen_by: organizer)

    perform(force_capture)

    expect(Stripe::Issuing::Card).not_to have_received(:update)
    expect(card.reload.last_frozen_by).to eq(organizer)
  end

  it "does nothing for a capture with an authorization" do
    rst = force_capture
    rst.update_columns(stripe_authorization_id: "iauth_123")

    perform(rst)

    expect(Stripe::Issuing::Card).not_to have_received(:update)
  end
end
