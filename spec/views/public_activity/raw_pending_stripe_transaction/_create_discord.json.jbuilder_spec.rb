# frozen_string_literal: true

require "rails_helper"

RSpec.describe "public_activity/raw_pending_stripe_transaction/_create_discord" do
  let(:user) { create(:user) }
  let(:event) { create(:event, name: "Hack Club HQ") }

  # Rendered the way Discord::ProcessNotificationJob renders it.
  def render_discord(raw)
    activity = PublicActivity::Activity.create!(trackable: raw.reload, key: "raw_pending_stripe_transaction.create", owner: user, recipient: user)
    JSON.parse(ApplicationController.renderer.render(partial: "public_activity/raw_pending_stripe_transaction/create_discord", locals: { activity:, p: { current_user: user } }))
  end

  it "links the charge and the view button to the ledger item" do
    raw = create(:raw_pending_stripe_transaction, amount_cents: -1500)
    cpt = create(:canonical_pending_transaction, raw_pending_stripe_transaction: raw, event:, amount_cents: -1500)
    ledger_item = cpt.reload.ledger_item

    json = render_discord(raw)

    expect(json["embed"]["description"]).to include("spent $15.00 on")
    expect(json["embed"]["description"]).to include(ledger_item_path(ledger_item))
    expect(json["embed"]["description"]).not_to include("/hcb/")
    expect(json["components"].first).to include("label" => "View transaction", "url" => a_string_ending_with(ledger_item_path(ledger_item)))
    expect(json["components"].last).to include("label" => "Attach receipt")
  end

  it "describes a refunded charge by the amount refunded, not the item's net amount" do
    stripe_card = create(:stripe_card, :with_stripe_id, event:)
    raw = create(:raw_pending_stripe_transaction, stripe_card:, amount_cents: -1500)
    cpt = create(:canonical_pending_transaction, raw_pending_stripe_transaction: raw, event:, amount_cents: -1500)
    create(:raw_stripe_transaction, stripe_card:, stripe_authorization_id: raw.stripe_transaction_id, amount_cents: -1500)
    refund = create(:raw_stripe_transaction, :refund, stripe_card:, stripe_authorization_id: raw.stripe_transaction_id, amount_cents: 2000)
    create(:canonical_transaction, transaction_source: refund, amount_cents: 2000)
    ledger_item = cpt.reload.ledger_item

    json = render_discord(raw)

    expect(ledger_item.linked_object).to be_stripe_refund
    expect(json["embed"]["description"]).to include("was refunded $20.00 from #{ledger_item.memo} for")
    expect(json["embed"]["description"]).to include(event_path(event))
  end

  it "leaves out the view button before the charge has a ledger item" do
    raw = create(:raw_pending_stripe_transaction, amount_cents: -1500)

    json = render_discord(raw)

    expect(json["embed"]["description"]).to include("spent $15.00 on merchant 1")
    expect(json["components"].map { |c| c["label"] }).to eq(["Attach receipt"])
  end
end
