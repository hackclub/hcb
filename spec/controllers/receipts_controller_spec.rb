# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReceiptsController do
  include SessionSupport

  describe "#create" do
    render_views

    it "swaps the receipt buttons on the item's ledger row for \"Uploaded!\"" do
      create_session(create(:user, :make_admin), verified: true)
      hcb_code = create(:canonical_pending_transaction).local_hcb_code
      ledger_item = hcb_code.ledger_item

      post(:create, params: {
             receiptable_type: "HcbCode",
             receiptable_id: hcb_code.id,
             upload_method: "receipts_page",
             file: [fixture_file_upload("receipt.png", "image/png")]
           }, format: :turbo_stream)

      stream = Nokogiri::HTML5.fragment(response.body).at_css("turbo-stream[target='receipt_action_ledger_item_#{ledger_item.id}']")
      expect(stream["action"]).to eq("replace")
      expect(stream.inner_html).to include("Uploaded!")
      expect(stream.inner_html).not_to include("Upload another receipt")
    end

    it "doesn't send the re-rendered no/lost link back to the upload endpoint" do
      create_session(create(:user, :make_admin), verified: true)
      hcb_code = create(:canonical_pending_transaction).local_hcb_code

      post(:create, params: {
             receiptable_type: "HcbCode",
             receiptable_id: hcb_code.id,
             upload_method: "transaction_page",
             file: [fixture_file_upload("receipt.png", "image/png")]
           }, format: :turbo_stream)

      expect(response.body).to include("No/lost receipt?")
      expect(response.body).not_to include("return_to")
    end

    it "streams the new receipt count into the item's ledger row" do
      create_session(create(:user, :make_admin), verified: true)
      hcb_code = create(:canonical_pending_transaction).local_hcb_code
      ledger_item = hcb_code.ledger_item

      post(:create, params: {
             receiptable_type: "HcbCode",
             receiptable_id: hcb_code.id,
             upload_method: "transaction_popover",
             file: [fixture_file_upload("receipt.png", "image/png")]
           }, format: :turbo_stream)

      stream = Nokogiri::HTML5.fragment(response.body).at_css("turbo-stream[target='badges_ledger_item_#{ledger_item.id}']")
      expect(stream["action"]).to eq("replace")
      expect(stream.inner_html).to include('aria-label="1 receipt"')
    end
  end

  context "models including Receiptable" do
    it "are explicitly registered" do
      Rails.application.eager_load!
      ApplicationRecord.descendants
                       .filter { _1.include?(Receiptable) }
                       .each do |klass|
        expect(ReceiptsController::RECEIPTABLE_TYPE_MAP).to have_key(klass.to_s)
      end
    end
  end
end
