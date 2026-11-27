# frozen_string_literal: true

require "rails_helper"

RSpec.describe SuggestedPairingsController do
  include SessionSupport
  render_views

  let(:user) { create(:user) }
  let(:event) { create(:event) }
  let(:stripe_card) { create(:stripe_card, :with_stripe_id, stripe_cardholder: create(:stripe_cardholder, user:), event:) }

  # A receipt in the user's bin paired with a pending card charge on their card.
  def create_pairing
    receipt = Receipt.new(user:, upload_method: :api)
    receipt.file.attach(io: File.open(file_fixture("receipt.png")), filename: "receipt.png", content_type: "image/png")
    receipt.save!
    raw_pending_stripe_transaction = create(:raw_pending_stripe_transaction, stripe_card:, amount_cents: -10_00)
    hcb_code = create(:canonical_pending_transaction, raw_pending_stripe_transaction:, amount_cents: -10_00, event:).local_hcb_code.reload
    SuggestedPairing.create!(receipt:, ledger_item: hcb_code.ledger_item, distance: 1)
  end

  describe "#accept" do
    it "attaches the receipt to the ledger item and links the flash to it" do
      create_session(user, verified: true)
      pairing = create_pairing

      post(:accept, params: { id: pairing.id })

      expect(pairing.reload).to be_accepted
      expect(pairing.receipt.reload.receiptable).to eq(pairing.ledger_item)
      expect(flash[:success][:link]).to eq(ledger_item_path(pairing.ledger_item))
    end

    it "streams the item's ledger row badges and receipt buttons, and removes the receipt from the bin" do
      create_session(user, verified: true)
      pairing = create_pairing

      post(:accept, params: { id: pairing.id }, format: :turbo_stream)

      fragment = Nokogiri::HTML5.fragment(response.body)
      targets = fragment.css("turbo-stream").map { |stream| [stream["action"], stream["target"]] }
      expect(targets).to include(["replace", "badges_ledger_item_#{pairing.ledger_item.id}"],
                                 ["replace", "receipt_action_ledger_item_#{pairing.ledger_item.id}"],
                                 ["remove", "receipt_#{pairing.receipt.id}"])
    end

    it "renames the transaction when asked to accept with the suggested memo" do
      create_session(user, verified: true)
      pairing = create_pairing
      pairing.receipt.update!(suggested_memo: "🍩 Donuts from Dunkin")

      post(:accept, params: { id: pairing.id, memo: "true" })

      expect(pairing.ledger_item.reload.memo).to eq("🍩 Donuts from Dunkin")
    end
  end

  describe "#ignore" do
    it "marks the pairing ignored" do
      create_session(user, verified: true)
      pairing = create_pairing

      post(:ignore, params: { id: pairing.id })

      expect(pairing.reload).to be_ignored
    end

    it "re-renders the remaining pairings with the ledger item row" do
      create_session(user, verified: true)
      pairing = create_pairing
      remaining = create_pairing
      remaining.ledger_item.update_columns(receipt_required: true, receipt_count: 0)

      post(:ignore, params: { id: pairing.id }, format: :turbo_stream)
      expect(response).to be_successful

      card = Nokogiri::HTML5.fragment(response.body).at_css("turbo-stream[target=suggested_pairings] template")
      row = card.at_css("tr.transaction")
      expect(row.at_css("a[href='#{ledger_item_path(remaining.ledger_item)}']")).to be_present
      expect(row.at_css("#badges_ledger_item_#{remaining.ledger_item.id}")).to be_present
      expect(row["data-controller"]).to be_nil
      expect(row.css("td").size).to eq(4) # icon, date, memo, amount: no author, no receipt buttons
    end
  end
end
