# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReceiptsController do
  include SessionSupport

  describe "#restore_original" do
    render_views

    let(:user) { create(:user) }
    let(:receipt) do
      turned = ImageProcessing::MiniMagick.source(file_fixture("rotation_receipt.png").to_s).rotate(90).call
      Receipt.create!(user:, upload_method: :api, file: { io: turned, filename: "receipt.png", content_type: "image/png" })
    end

    it "shows that a receipt was rotated, and puts the upload back when asked" do
      create_session(user, verified: true)
      details = -> { controller.render_to_string(partial: "receipts/details", locals: { receipt: receipt.reload }) }
      get(:link_modal) # gives the controller a request to render the partial in
      expect(details.call).to include("Undo rotation", "View original")

      post(:restore_original, params: { id: receipt.id })

      expect(receipt.reload.file.blob).to eq(receipt.original_file.blob)
      expect(details.call).not_to include("Undo rotation")
    end

    it "doesn't let someone else undo it" do
      create_session(create(:user), verified: true)
      rotated = receipt.file.blob

      post(:restore_original, params: { id: receipt.id })

      expect(receipt.reload.file.blob).to eq(rotated)
    end
  end

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
