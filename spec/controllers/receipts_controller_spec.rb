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

  describe "#create when the upload fails" do
    render_views

    let(:ledger_item) { create(:canonical_pending_transaction).local_hcb_code.ledger_item }
    let(:file) { [fixture_file_upload("receipt.png", "image/png")] }
    let(:fragment) { Nokogiri::HTML5.fragment(response.body) }

    before do
      receipt = Receipt.new
      receipt.errors.add(:file, "is not a supported type")
      allow_any_instance_of(ReceiptService::Create).to receive(:run!).and_raise(ActiveRecord::RecordInvalid.new(receipt))
    end

    it "shows the error on the transaction's own upload form" do
      create_session(create(:user, :make_admin), verified: true)

      post(:create, params: {
             receiptable_type: "Ledger::Item",
             receiptable_id: ledger_item.id,
             upload_method: "transaction_page",
             file:
           }, format: :turbo_stream)

      stream = fragment.at_css("turbo-stream[target='#{ledger_item.id}_receipt_upload_form']")
      expect(stream["action"]).to eq("replace")
      form = Nokogiri::HTML5.fragment(stream.at_css("template").inner_html)
      expect(form.at_css("#upload-receipt-button").text).to include("File is not a supported type")
      expect(form.at_css("#upload-receipt-button")["disabled"]).to be_nil
      expect(form.at_css("input[name='receiptable_type']")["value"]).to eq("Ledger::Item")
      expect(form.at_css("input[name='receiptable_id']")["value"]).to eq(ledger_item.id.to_s)
      expect(form.at_css("input[name='upload_method']")["value"]).to eq("transaction_page")
      expect(fragment.at_css("turbo-stream[target='receipt_upload_form']")).to be_nil
    end

    it "keeps a popover's upload form posting as a popover" do
      create_session(create(:user, :make_admin), verified: true)
      hcb_code = ledger_item.hcb_code
      request.headers["Referer"] = hcb_code_url(hcb_code)

      post(:create, params: {
             receiptable_type: "Ledger::Item",
             receiptable_id: ledger_item.id,
             upload_method: "transaction_popover_drag_and_drop",
             file:
           }, format: :turbo_stream)

      form = Nokogiri::HTML5.fragment(fragment.at_css("turbo-stream[target='#{ledger_item.id}_receipt_upload_form'] template").inner_html)
      expect(form.at_css("input[name='popover']")["value"]).to eq("HcbCode:#{hcb_code.hashid}")
      expect(form.at_css("input[name='show_link']")["value"]).to eq("true")
      expect(form.at_css("input[name='upload_method']")["value"]).to eq("transaction_popover")
    end

    it "shows the error on the Receipt Bin form when there's no receiptable" do
      create_session(create(:user), verified: true)

      post(:create, params: { upload_method: "receipt_center", file: }, format: :turbo_stream)

      stream = fragment.at_css("turbo-stream[target='receipt_upload_form']")
      expect(stream["action"]).to eq("replace")
      expect(stream.inner_html).to include("File is not a supported type")
    end

    it "doesn't render the transaction's upload form for a user who can't upload to it" do
      create_session(create(:user), verified: true)

      post(:create, params: {
             receiptable_type: "Ledger::Item",
             receiptable_id: ledger_item.id,
             upload_method: "transaction_page",
             file:
           }, format: :turbo_stream)

      expect(fragment.at_css("turbo-stream[target='#{ledger_item.id}_receipt_upload_form']")).to be_nil
      expect(response.body).not_to include("receiptable_id")
    end

    it "flashes the error for an upload from a ledger row, which has no upload form" do
      create_session(create(:user, :make_admin), verified: true)

      post(:create, params: {
             receiptable_type: "Ledger::Item",
             receiptable_id: ledger_item.id,
             upload_method: "receipts_page",
             file:
           }, format: :turbo_stream)

      expect(fragment.at_css("turbo-stream[target='flash-container']").inner_html).to include("There was an error uploading your receipt")
      expect(fragment.css("turbo-stream").map { |stream| stream["target"] }).to eq(["flash-container"])
    end

    it "flashes the error and resets the upload button for a reimbursement expense" do
      create_session(create(:user, :make_admin), verified: true)
      expense = create(:reimbursement_expense)

      post(:create, params: {
             receiptable_type: "Reimbursement::Expense",
             receiptable_id: expense.id,
             upload_method: "expense_report",
             file:
           }, format: :turbo_stream)

      expect(fragment.css("turbo-stream").map { |stream| stream["target"] }).to eq(["flash-container", "receipts_for_#{expense.id}"])
    end

    it "doesn't show the message of an unexpected error" do
      create_session(create(:user, :make_admin), verified: true)
      allow_any_instance_of(ReceiptService::Create).to receive(:run!).and_raise(StandardError, "internal detail")

      post(:create, params: {
             receiptable_type: "Ledger::Item",
             receiptable_id: ledger_item.id,
             upload_method: "transaction_page",
             file:
           }, format: :turbo_stream)

      expect(response.body).to include("Upload failed")
      expect(response.body).not_to include("internal detail")
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
