# frozen_string_literal: true

require "rails_helper"

RSpec.describe StaticPagesController do
  include SessionSupport

  describe "#receipt (Receipt Bin upload)" do
    let(:user) { create(:user) }

    before { create_session(user, verified: true) }

    def upload(file)
      post(:receipt, params: { upload_method: "receipts_page", redirect_url: "/my/inbox", file: [file] })
    end

    it "adds the receipt to the bin" do
      upload(fixture_file_upload("receipt.png", "image/png"))

      expect(flash[:success]).to eq("Receipt added!")
      expect(flash[:error]).to be_nil
      expect(Receipt.in_receipt_bin.where(user:).count).to eq(1)
      expect(response).to redirect_to("/my/inbox")
    end

    it "says an unsupported file type was rejected, without reporting it" do
      expect(Rails.error).not_to receive(:report)

      upload(fixture_file_upload("attachment1.txt", "text/plain"))

      expect(flash[:error]).to eq("File type isn't supported. Upload an image, PDF, or CSV.")
      expect(Receipt.count).to eq(0)
      expect(response).to redirect_to("/my/inbox")
    end

    it "says the file is over 50 MB" do
      blob = ActiveStorage::Blob.create_and_upload!(
        io: Rails.root.join("spec/fixtures/files/receipt.png").open, filename: "big.png", content_type: "image/png"
      )
      blob.update_column(:byte_size, 50.megabytes + 1) # avoids allocating 50 MB

      upload(blob.signed_id)

      expect(flash[:error]).to eq("File is over 50 MB. Upload a smaller file.")
      expect(Receipt.count).to eq(0)
    end

    it "shows the generic message for any other error and reports it" do
      error = StandardError.new("S3 is down")
      allow(ReceiptService::Create).to receive(:new).and_raise(error)
      expect(Rails.error).to receive(:report).with(error)

      upload(fixture_file_upload("receipt.png", "image/png"))

      expect(flash[:error]).to eq("There was an error uploading your receipt. Please try again.")
    end
  end
end
