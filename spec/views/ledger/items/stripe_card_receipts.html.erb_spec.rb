# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ledger/items/_stripe_card_receipts" do
  let(:card_charge) { create(:raw_pending_stripe_transaction).reload.card_charge }
  let(:ledger_item) { create(:ledger_item, linked_object: card_charge) }

  # The banner reads the cached receipt columns and the status that refresh!
  # computes, so set them directly rather than building the transactions
  # behind each state.
  def render_banner(**columns)
    ledger_item.update_columns(columns)
    render partial: "ledger/items/stripe_card_receipts", locals: { ledger_item: }
  end

  it "counts the receipts once the charge has some" do
    render_banner(receipt_count: 2, receipt_required: true)

    expect(rendered).to include("2 receipts")
  end

  it "says the charge was marked no/lost receipt" do
    render_banner(marked_no_or_lost_receipt_at: Time.current, receipt_required: true)

    expect(rendered).to include("Marked no/lost receipt")
  end

  it "says the charge is missing a receipt while one is required" do
    render_banner(receipt_required: true)

    expect(rendered).to include("This transaction is missing a receipt")
  end

  it "renders nothing when no receipt is required" do
    render_banner(receipt_required: false)

    expect(rendered).not_to include("receipt")
  end

  # A declined charge never settles, so it doesn't need a receipt; it used to
  # get a "This transaction has no receipt" banner.
  it "renders nothing for a declined charge" do
    render_banner(status: "declined", receipt_required: true)

    expect(rendered).not_to include("receipt")
  end
end
