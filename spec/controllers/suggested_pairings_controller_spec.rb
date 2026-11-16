# frozen_string_literal: true

require "rails_helper"

RSpec.describe SuggestedPairingsController do
  include SessionSupport
  render_views

  let(:user) { create(:user) }

  def create_pairing
    receipt = Receipt.new(user:, upload_method: :api)
    receipt.file.attach(io: File.open(file_fixture("receipt.png")), filename: "receipt.png", content_type: "image/png")
    receipt.save!
    hcb_code = create(:canonical_pending_transaction, amount_cents: -10_00).local_hcb_code
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
  end
end
