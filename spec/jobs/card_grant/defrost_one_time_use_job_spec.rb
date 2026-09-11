# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardGrant::DefrostOneTimeUseJob do
  let(:system_user) { create(:user, email: User::SYSTEM_USER_EMAIL) }
  let(:card_grant) { create(:card_grant, event: create(:event, :with_positive_balance), one_time_use: true) }
  let(:card) { card_grant.stripe_card }

  before do
    allow(User).to receive(:system_user).and_return(system_user)
    allow(Stripe::Issuing::Card).to receive(:update)
    allow(Stripe::Issuing::Card).to receive(:retrieve).and_return(
      Stripe::Issuing::Card.construct_from(
        id: card.stripe_id,
        status: "active",
        type: "virtual",
        brand: "Visa",
        exp_month: 2,
        exp_year: 2030,
        last4: "9876",
        spending_controls: { spending_limits: [] }
      )
    )
  end

  def freeze_by(user)
    card.update!(stripe_status: "inactive", initially_activated: true, last_frozen_by: user)
  end

  def card_charge_for(stripe_card)
    create(
      :raw_pending_stripe_transaction,
      stripe_transaction: {
        "id"                   => "iauth_#{SecureRandom.hex(6)}",
        "card"                 => { "id" => stripe_card.stripe_id },
        "authorization_method" => "online",
        "merchant_data"        => { "name" => "merchant", "category" => "bakeries" }
      }
    ).card_charge
  end

  def ledger_item_for(card_charge, status:)
    item = Ledger::Item.new(amount_cents: 0, memo: "Test", datetime: Time.current, linked_object: card_charge)
    item.save(validate: false)
    item.update_columns(status:)
    item
  end

  def perform(item)
    described_class.perform_now(ledger_item_id: item.id)
  end

  it "defrosts the card when a one-time-use charge is fully refunded, keeping the grant one-time-use" do
    freeze_by(system_user)
    item = ledger_item_for(card_charge_for(card), status: "reversed")

    expect(Stripe::Issuing::Card).to receive(:update).with(card.stripe_id, status: :active)

    perform(item)

    expect(card.reload).to be_active
    expect(card_grant.reload.one_time_use).to eq(true)
  end

  it "defrosts the card when the authorization was released without capture" do
    freeze_by(system_user)
    item = ledger_item_for(card_charge_for(card), status: "released")

    perform(item)

    expect(card.reload).to be_active
  end

  it "ignores an earlier charge that already settled" do
    freeze_by(system_user)
    ledger_item_for(card_charge_for(card), status: "settled")
    item = ledger_item_for(card_charge_for(card), status: "reversed")

    perform(item)

    expect(card.reload).to be_active
  end

  it "does nothing when a newer charge on the card is still pending" do
    freeze_by(system_user)
    item = ledger_item_for(card_charge_for(card), status: "reversed")
    ledger_item_for(card_charge_for(card), status: "pending")

    perform(item)

    expect(Stripe::Issuing::Card).not_to have_received(:update)
    expect(card.reload).to be_frozen
  end

  it "does nothing when a newer charge on the card has settled" do
    freeze_by(system_user)
    item = ledger_item_for(card_charge_for(card), status: "reversed")
    ledger_item_for(card_charge_for(card), status: "settled")

    perform(item)

    expect(Stripe::Issuing::Card).not_to have_received(:update)
    expect(card.reload).to be_frozen
  end

  it "does nothing when the grant is not one-time-use" do
    card_grant.update!(one_time_use: false)
    freeze_by(system_user)
    item = ledger_item_for(card_charge_for(card), status: "reversed")

    perform(item)

    expect(Stripe::Issuing::Card).not_to have_received(:update)
    expect(card.reload).to be_frozen
  end

  it "does nothing when the card is not frozen" do
    item = ledger_item_for(card_charge_for(card), status: "reversed")

    perform(item)

    expect(Stripe::Issuing::Card).not_to have_received(:update)
  end

  it "does not undo a freeze made by a person" do
    freeze_by(create(:user))
    item = ledger_item_for(card_charge_for(card), status: "reversed")

    perform(item)

    expect(Stripe::Issuing::Card).not_to have_received(:update)
    expect(card.reload).to be_frozen
  end

  it "leaves the card frozen when the organization is financially frozen" do
    freeze_by(system_user)
    card.event.update!(financially_frozen: true)
    item = ledger_item_for(card_charge_for(card), status: "reversed")

    perform(item)

    expect(Stripe::Issuing::Card).not_to have_received(:update)
    expect(card.reload).to be_frozen
  end

  it "does nothing when the item is no longer reversed or released" do
    freeze_by(system_user)
    item = ledger_item_for(card_charge_for(card), status: "settled")

    perform(item)

    expect(Stripe::Issuing::Card).not_to have_received(:update)
    expect(card.reload).to be_frozen
  end

  it "does not raise for a missing ledger item id" do
    expect { described_class.perform_now(ledger_item_id: -1) }.not_to raise_error
  end

  %w[canceled expired].each do |status|
    it "does not defrost a #{status} grant" do
      freeze_by(system_user)
      card_grant.update!(status:)
      item = ledger_item_for(card_charge_for(card), status: "reversed")

      perform(item)

      expect(Stripe::Issuing::Card).not_to have_received(:update)
      expect(card.reload).to be_frozen
    end
  end

  it "does not activate the card again when the job is repeated" do
    freeze_by(system_user)
    item = ledger_item_for(card_charge_for(card), status: "reversed")

    2.times { perform(item) }

    expect(Stripe::Issuing::Card).to have_received(:update).once
    expect(card_grant.reload).to be_one_time_use
  end

  it "reports a permanent Stripe rejection without retrying" do
    freeze_by(system_user)
    item = ledger_item_for(card_charge_for(card), status: "reversed")
    error = Stripe::InvalidRequestError.new("Card is canceled", "status")
    allow(Stripe::Issuing::Card).to receive(:update).and_raise(error)
    expect(Rails.error).to receive(:report).with(error)

    expect { perform(item) }.not_to raise_error

    expect(card.reload).to be_frozen
  end
end
