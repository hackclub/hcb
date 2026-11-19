# frozen_string_literal: true

require "rails_helper"

RSpec.describe "public_activity/raw_pending_stripe_transaction/_create" do
  let(:user) { create(:user) }
  let(:event) { create(:event, name: "Hack Club HQ") }

  before do
    def view.current_user = nil
  end

  def create_authorization(**options)
    raw = create(:raw_pending_stripe_transaction, amount_cents: -1500, **options)
    cpt = create(:canonical_pending_transaction, raw_pending_stripe_transaction: raw, event:, memo: "Lunch", amount_cents: -1500)
    [raw, cpt]
  end

  def render_activity(raw)
    # The feed loads records fresh, so drop the associations the factories cached.
    activity = PublicActivity::Activity.create!(trackable: raw.reload, key: "raw_pending_stripe_transaction.create", owner: user)
    render partial: "public_activity/raw_pending_stripe_transaction/create", locals: { activity:, p: {}, current_user: user }
    Nokogiri::HTML(rendered)
  end

  it "links a card charge to its ledger item" do
    raw, cpt = create_authorization
    ledger_item = cpt.reload.ledger_item

    html = render_activity(raw)

    expect(html.text.squish).to include("You spent $15.00 on #{ledger_item.memo} for Hack Club HQ")
    expect(html.css("a").map { |a| a["href"] }).to include(ledger_item_path(ledger_item))
    expect(html.css("a").map { |a| a["href"] }).not_to include(a_string_matching(/\/hcb\//))
  end

  it "describes a declined authorization" do
    raw, cpt = create_authorization
    cpt.decline!
    ledger_item = cpt.reload.ledger_item

    html = render_activity(raw)

    expect(ledger_item).to be_declined
    expect(html.text.squish).to include("Your Hack Club HQ card was declined for $15.00 at #{ledger_item.memo}")
    expect(html.css("a").map { |a| a["href"] }).to include(ledger_item_path(ledger_item))
  end

  it "describes a cash withdrawal" do
    raw, cpt = create_authorization(stripe_merchant_category_code: "6011")
    ledger_item = cpt.reload.ledger_item

    html = render_activity(raw)

    expect(html.text.squish).to include("You withdrew $15.00 from Merchant 1 for Hack Club HQ")
    expect(html.css("a").map { |a| a["href"] }).to include(ledger_item_path(ledger_item))
  end

  it "falls back to the raw transaction before it has a ledger item" do
    raw = create(:raw_pending_stripe_transaction, amount_cents: -1500)

    html = render_activity(raw)

    expect(html.text.squish).to include("You spent $15.00 on merchant 1")
    expect(html.css("a")).to be_empty
  end
end
