# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Renaming a transaction from its page", type: :system do
  let(:user) { create(:user, phone_number: "+18556254225") }
  let(:event) { create(:event) }
  let(:card) { create(:stripe_card, :with_stripe_id, event:, stripe_cardholder: create(:stripe_cardholder, user:)) }
  let(:charge) do
    raw_pending_stripe_transaction = create(:raw_pending_stripe_transaction, stripe_card: card, amount_cents: -1234, stripe_merchant_category_code: "5462")
    create(:canonical_pending_transaction, raw_pending_stripe_transaction:, amount_cents: -1234, event:)
  end
  let(:item) { charge.local_hcb_code.ledger_item }
  let(:heading) { "h2.hcb-code--heading" }
  let(:ai_memo_button) { "#{heading} [data-memo-suggestion-param]" }
  let(:memo_input) { "##{ActionView::RecordIdentifier.dom_id(item)}_heading_memo" }

  before do
    create(:organizer_position_invite, :accepted, event:, user:)
    Receipt.create!(receiptable: item, user:, upload_method: :api, suggested_memo: "☕ Coffee from Cafe",
                    file: { io: file_fixture("receipt.png").open, filename: "receipt.png" })

    sign_in(user)
    visit ledger_item_path(item)
  end

  def rename_to(memo)
    find("#{heading} [aria-label='Rename']").click
    find(memo_input).fill_in(with: memo).send_keys(:enter)
  end

  it "swaps the heading between the charge's description and the memo without a reload" do
    expect(page).to have_css(heading, text: "Purchase at")
    expect(page).to have_css(ai_memo_button)

    rename_to("Team lunch")

    # The heading now shows the memo itself, and the AI suggestion is
    # withdrawn because there's a custom memo to keep.
    expect(page).to have_css(heading, text: "Team lunch for $12.34")
    expect(page).to have_no_css(heading, text: "Purchase at")
    expect(page).to have_no_css(ai_memo_button)
    expect(item.reload.custom_memo).to eq("Team lunch")

    rename_to("")

    # Clearing the memo falls back to the charge's own description and offers
    # the AI suggestion again.
    expect(page).to have_css(heading, text: "Purchase at")
    expect(page).to have_no_css(heading, text: "Team lunch")
    expect(page).to have_css(ai_memo_button)
    expect(item.reload.custom_memo).to be_nil
  end
end
