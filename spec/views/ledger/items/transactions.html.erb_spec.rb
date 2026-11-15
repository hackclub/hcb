# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ledger/items/_transactions" do
  let(:ledger_item) { create(:ledger_item) }

  before do
    # `admin_tool` checks the signed-in user; render as a signed-out visitor.
    def view.current_user = nil
  end

  def render_transactions
    render partial: "ledger/items/transactions", locals: { ledger_item: }
  end

  it "renders the decline of a pending transaction as its own row" do
    raw = create(:raw_pending_stripe_transaction)
    raw.update!(stripe_transaction: raw.stripe_transaction.merge("request_history" => [{ "reason" => "insufficient_funds" }]))
    cpt = create(:canonical_pending_transaction, ledger_item:, memo: "Declined charge", raw_pending_stripe_transaction: raw)
    cpt.decline!

    render_transactions

    expect(rendered).to include("Declined charge")
    expect(rendered).to include("Declined")
    expect(rendered).to include("Insufficient funds")
    expect(rendered).to include(cpt.canonical_pending_declined_mapping.created_at.strftime("%b %e, %Y"))
    expect(rendered.index("Declined charge")).to be < rendered.index("Insufficient funds")
  end

  it "says so when the decline reason is unknown" do
    cpt = create(:canonical_pending_transaction, ledger_item:, memo: "Declined charge")
    cpt.decline!

    render_transactions

    expect(rendered).to include("No decline reason recorded")
  end

  it "groups a settled canonical transaction under the pending transaction it settled from" do
    cpt = create(:canonical_pending_transaction, ledger_item:, memo: "Pending charge", date: Date.new(2026, 1, 1))
    ct = create(:canonical_transaction, ledger_item:, memo: "Settled charge", date: Date.new(2026, 1, 3))
    create(:canonical_pending_settled_mapping, canonical_pending_transaction: cpt, canonical_transaction: ct)

    render_transactions

    # Rendered once, nested under the pending transaction, rather than as its own row too.
    expect(rendered.scan("Settled charge").size).to eq(1)
    expect(rendered.index("Pending charge")).to be < rendered.index("Settled charge")
    expect(rendered).to include("↳")
  end

  it "renders a canonical transaction without a pending transaction on its own" do
    create(:canonical_transaction, ledger_item:, memo: "Standalone charge")

    render_transactions

    expect(rendered).to include("Standalone charge")
    expect(rendered).not_to include("↳")
  end
end
