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

  it "leaves out the view button before the charge has a ledger item" do
    raw = create(:raw_pending_stripe_transaction, amount_cents: -1500)

    json = render_discord(raw)

    expect(json["embed"]["description"]).to include("spent $15.00 on merchant 1")
    expect(json["components"].map { |c| c["label"] }).to eq(["Attach receipt"])
  end
end
