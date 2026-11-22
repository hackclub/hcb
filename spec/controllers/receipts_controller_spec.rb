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
             receiptable_type: "Ledger::Item",
             receiptable_id: hcb_code.ledger_item.id,
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
             receiptable_type: "Ledger::Item",
             receiptable_id: hcb_code.ledger_item.id,
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
             receiptable_type: "Ledger::Item",
             receiptable_id: hcb_code.ledger_item.id,
             upload_method: "transaction_popover",
             file: [fixture_file_upload("receipt.png", "image/png")]
           }, format: :turbo_stream)

      stream = Nokogiri::HTML5.fragment(response.body).at_css("turbo-stream[target='badges_ledger_item_#{ledger_item.id}']")
      expect(stream["action"]).to eq("replace")
      expect(stream.inner_html).to include('aria-label="1 receipt"')
    end
  end

  # Receipts are moving onto ledger items (#14106); the controller has to drive
  # the same HCB code specific streams and redirects from either receiptable.
  describe "with a Ledger::Item receiptable" do
    render_views

    let(:hcb_code) { create(:canonical_pending_transaction).local_hcb_code.reload }
    let(:ledger_item) { hcb_code.ledger_item }

    before { create_session(create(:user, :make_admin), verified: true) }

    it "#create attaches the receipt and streams the HCB code's receipt list and ledger row" do
      post(:create, params: {
             receiptable_type: "Ledger::Item",
             receiptable_id: ledger_item.id,
             upload_method: "receipts_page",
             file: [fixture_file_upload("receipt.png", "image/png")]
           }, format: :turbo_stream)

      expect(Receipt.last.receiptable).to eq(ledger_item)
      expect(hcb_code.receipts.count).to eq(1)

      fragment = Nokogiri::HTML5.fragment(response.body)
      expect(fragment.at_css("turbo-stream[target='#{hcb_code.hashid}']")["action"]).to eq("replace")
      stream = fragment.at_css("turbo-stream[target='receipt_action_ledger_item_#{ledger_item.id}']")
      expect(stream.inner_html).to include("Uploaded!")
    end

    # A transaction's page lists the earlier charges of its subscription, and a
    # receipt can be dropped on any of those rows.
    describe "#create from an HCB code page" do
      def upload
        post(:create, params: {
               receiptable_type: "Ledger::Item",
               receiptable_id: ledger_item.id,
               upload_method: "receipts_page_drag_and_drop",
               show_receipt_button: "true",
               file: [fixture_file_upload("receipt.png", "image/png")]
             }, format: :turbo_stream)

        Nokogiri::HTML5.fragment(response.body)
      end

      it "updates the page's receipt list when the receipt is for that page's transaction" do
        request.headers["Referer"] = hcb_code_url(hcb_code)

        fragment = upload

        expect(fragment.at_css("turbo-stream[target='receipts_list']")).to be_present
        expect(fragment.at_css("turbo-stream[target='_receipts_list']")).to be_present
      end

      it "leaves the page's receipt list alone when the receipt is for another transaction listed on it" do
        request.headers["Referer"] = hcb_code_url(create(:canonical_pending_transaction).local_hcb_code)

        fragment = upload

        expect(Receipt.last.receiptable).to eq(ledger_item)
        expect(fragment.at_css("turbo-stream[target='receipts_list']")).to be_nil
        expect(fragment.at_css("turbo-stream[target='_receipts_list']")).to be_nil
        expect(fragment.at_css("turbo-stream[target='_stripe_card_receipts']")).to be_nil
        expect(fragment.at_css("turbo-stream[target='#{hcb_code.hashid}']").inner_html).to include("Uploaded!")
      end
    end

    it "#link from another transaction's HCB code page doesn't add the receipt to that page's list" do
      receipt = ::ReceiptService::Create.new(
        receiptable: nil,
        uploader: User.last,
        attachments: [fixture_file_upload("receipt.png", "image/png")],
        upload_method: :receipts_page
      ).run!.first
      request.headers["Referer"] = hcb_code_url(create(:canonical_pending_transaction).local_hcb_code)

      post(:link, params: {
             receipt_id: receipt.id,
             receiptable_type: "Ledger::Item",
             receiptable_id: ledger_item.id
           }, format: :turbo_stream)

      expect(receipt.reload.receiptable).to eq(ledger_item)
      expect(Nokogiri::HTML5.fragment(response.body).at_css("turbo-stream[target='receipts_list']")).to be_nil
    end

    it "#create shows a failed upload in the page's flash" do
      allow(::ReceiptService::Create).to receive(:new).and_raise(ActiveRecord::RecordInvalid)

      post(:create, params: {
             receiptable_type: "Ledger::Item",
             receiptable_id: ledger_item.id,
             upload_method: "receipts_page_drag_and_drop",
             file: [fixture_file_upload("receipt.png", "image/png")]
           }, format: :turbo_stream)

      stream = Nokogiri::HTML5.fragment(response.body).at_css("turbo-stream[target='flash-container']")
      expect(stream.inner_html).to include("There was an error uploading your receipt")
    end

    it "#create links the flash to the HCB code page" do
      post(:create, params: {
             receiptable_type: "Ledger::Item",
             receiptable_id: ledger_item.id,
             upload_method: "receipts_page",
             show_link: true,
             file: [fixture_file_upload("receipt.png", "image/png")]
           }, format: :html)

      expect(flash[:success][:link]).to eq(hcb_code_path(hcb_code))
    end

    it "#link attaches a receipt from the bin and links the flash to the HCB code page" do
      receipt = ::ReceiptService::Create.new(
        receiptable: nil,
        uploader: User.last,
        attachments: [fixture_file_upload("receipt.png", "image/png")],
        upload_method: :receipts_page
      ).run!.first

      post(:link, params: {
             receipt_id: receipt.id,
             receiptable_type: "Ledger::Item",
             receiptable_id: ledger_item.id,
             show_link: true
           }, format: :html)

      expect(receipt.reload.receiptable).to eq(ledger_item)
      expect(hcb_code.receipts).to contain_exactly(receipt)
      expect(flash[:success][:link]).to eq(hcb_code_path(hcb_code))
    end
  end

  context "models including Receiptable" do
    it "are explicitly registered" do
      Rails.application.eager_load!
      ApplicationRecord.descendants
                       .filter { _1.include?(Receiptable) }
                       .each do |klass|
        # A transaction's receipts go on its ledger item, not its HCB code (#14106).
        next if klass == HcbCode

        expect(ReceiptsController::RECEIPTABLE_TYPE_MAP).to have_key(klass.to_s)
      end
    end

    it "do not include HcbCode" do
      expect(ReceiptsController::RECEIPTABLE_TYPE_MAP).not_to have_key("HcbCode")
    end
  end
end
