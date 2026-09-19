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

  def card_charge_for(stripe_card, approved: true)
    create(
      :raw_pending_stripe_transaction,
      stripe_transaction: {
        "id"                   => "iauth_#{SecureRandom.hex(6)}",
        "approved"             => approved,
        "card"                 => { "id" => stripe_card.stripe_id },
        "authorization_method" => "online",
        "merchant_data"        => { "name" => "merchant", "category" => "bakeries" }
      }
    ).card_charge
  end

  def ledger_item_for(card_charge, status:, pending_at: Time.current, datetime: pending_at || Time.current)
    item = Ledger::Item.new(amount_cents: 0, memo: "Test", datetime:, pending_at:, linked_object: card_charge)
    item.save(validate: false)
    item.update_columns(status:, pending_at:, datetime:)
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

  it "uses authorization time when an older charge is inserted after the freezing charge" do
    freeze_by(system_user)
    item = ledger_item_for(card_charge_for(card), status: "reversed", pending_at: 1.day.ago)
    ledger_item_for(card_charge_for(card), status: "settled", pending_at: 2.days.ago, datetime: Time.current)

    perform(item)

    expect(card.reload).to be_active
  end

  it "does not defrost for an older authorization inserted after the freezing charge" do
    freeze_by(system_user)
    ledger_item_for(card_charge_for(card), status: "settled", pending_at: 1.day.ago)
    item = ledger_item_for(card_charge_for(card), status: "reversed", pending_at: 2.days.ago, datetime: Time.current)

    perform(item)

    expect(Stripe::Issuing::Card).not_to have_received(:update)
    expect(card.reload).to be_frozen
  end

  it "defrosts the reversed authorization despite a later-imported force capture" do
    freeze_by(system_user)
    item = ledger_item_for(card_charge_for(card), status: "reversed", pending_at: 1.day.ago)
    force_capture = create(:raw_stripe_transaction, stripe_card: card).card_charge
    ledger_item_for(force_capture, status: "settled", pending_at: nil)

    perform(item)

    expect(card.reload).to be_active
  end

  it "does not defrost when a force capture is refunded" do
    freeze_by(system_user)
    ledger_item_for(card_charge_for(card), status: "settled", pending_at: 1.day.ago)
    force_capture = create(:raw_stripe_transaction, stripe_card: card).card_charge
    item = ledger_item_for(force_capture, status: "reversed", pending_at: nil)

    perform(item)

    expect(Stripe::Issuing::Card).not_to have_received(:update)
    expect(card.reload).to be_frozen
  end

  it "defrosts a refunded purchase despite a later declined authorization" do
    freeze_by(system_user)
    item = ledger_item_for(card_charge_for(card), status: "reversed", pending_at: 1.day.ago)
    ledger_item_for(card_charge_for(card, approved: false), status: "declined")

    perform(item)

    expect(card.reload).to be_active
  end

  it "does not treat an unapproved authorization as the cause of a freeze" do
    freeze_by(system_user)
    item = ledger_item_for(card_charge_for(card, approved: false), status: "reversed")

    perform(item)

    expect(Stripe::Issuing::Card).not_to have_received(:update)
    expect(card.reload).to be_frozen
  end

  it "falls back to datetime for authorization items without pending_at" do
    freeze_by(system_user)
    item = ledger_item_for(card_charge_for(card), status: "reversed", pending_at: nil, datetime: 1.day.ago)
    ledger_item_for(card_charge_for(card), status: "settled", pending_at: nil, datetime: 2.days.ago)

    perform(item)

    expect(card.reload).to be_active
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
