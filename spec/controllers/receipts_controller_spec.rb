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

    it "says why an unsupported file type was rejected" do
      create_session(create(:user, :make_admin), verified: true)
      hcb_code = create(:canonical_pending_transaction).local_hcb_code
      params = {
        receiptable_type: "HcbCode",
        receiptable_id: hcb_code.id,
        upload_method: "transaction_page",
        file: [fixture_file_upload("attachment1.txt", "text/plain")]
      }

      post(:create, params:)
      expect(flash[:error]).to eq("File type isn't supported. Upload an image, PDF, or CSV.")

      post(:create, params:, format: :turbo_stream)
      expect(response.body).to include("File type isn&#39;t supported. Upload an image, PDF, or CSV.")
      expect(response.body).not_to include("Validation failed")
    end

    context "when an upload is rejected" do
      let(:user) { create(:user) }

      before { create_session(user, verified: true) }

      # A blob that claims to be over the limit, so the spec never allocates 50 MB.
      def oversized_blob
        ActiveStorage::Blob.create_and_upload!(
          io: Rails.root.join("spec/fixtures/files/receipt.png").open, filename: "big.png", content_type: "image/png"
        ).tap { |blob| blob.update_column(:byte_size, 50.megabytes + 1) }
      end

      it "does not report an unsupported file type to the error tracker" do
        expect(Rails.error).not_to receive(:report)

        post(:create, params: { upload_method: "receipt_center", file: [fixture_file_upload("attachment1.txt", "text/plain")] })

        expect(flash[:error]).to eq("File type isn't supported. Upload an image, PDF, or CSV.")
        expect(Receipt.count).to eq(0)
      end

      it "says the file is over 50 MB" do
        params = { upload_method: "receipt_center", file: [oversized_blob.signed_id] }

        post(:create, params:)
        expect(flash[:error]).to eq("File is over 50 MB. Upload a smaller file.")

        post(:create, params:, format: :turbo_stream)
        expect(response.body).to include("File is over 50 MB. Upload a smaller file.")
        expect(response.body).not_to include("Validation failed")
        expect(Receipt.count).to eq(0)
      end

      it "shows the generic message and reports any other error" do
        error = StandardError.new("S3 is down")
        allow(ReceiptService::Create).to receive(:new).and_raise(error)
        expect(Rails.error).to receive(:report).with(error).twice

        params = { upload_method: "receipt_center", file: [fixture_file_upload("receipt.png", "image/png")] }

        post(:create, params:)
        expect(flash[:error]).to eq("There was an error uploading your receipt. Please try again.")

        post(:create, params:, format: :turbo_stream)
        expect(response.body).to include("There was an error uploading your receipt. Please try again.")
        expect(response.body).not_to include("S3 is down")
      end
    end

    it "still says a successful upload was added" do
      create_session(create(:user), verified: true)

      post(:create, params: { upload_method: "receipt_center", file: [fixture_file_upload("receipt.png", "image/png")] })

      expect(flash[:success]).to eq("Receipt added!")
      expect(flash[:error]).to be_nil
      expect(Receipt.last.user).to eq(User.last)
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
