# frozen_string_literal: true

require "rails_helper"

# CSV previews are drawn in-process by the csv_preview gem (libvips + Pango), which replaced the
# LibreOffice-based previewer.
RSpec.describe "CSV previews" do
  def create_blob(content, filename:, content_type:)
    ActiveStorage::Blob.create_and_upload!(io: StringIO.new(content), filename:, content_type:, identify: false)
  end

  it "registers the csv_preview previewer" do
    expect(ActiveStorage.previewers).to include(CsvPreview::ActiveStoragePreviewer)
  end

  context "with libvips text support" do
    before do
      # CI installs libvips, so a missing install fails there instead of skipping.
      skip "libvips with Pango is not installed" unless CsvPreview.text_supported? || ENV["CI"]
    end

    it "renders a CSV blob as a PNG" do
      blob = create_blob("Merchant,Amount\nHack Club,12.34\n", filename: "receipt.csv", content_type: "text/csv")

      expect(blob).to be_previewable
      image = blob.preview(resize_to_limit: [500, 500]).processed.image

      expect(image).to be_attached
      expect(image.content_type).to eq("image/png")
      expect(image.download.byteslice(0, 8)).to eq("\x89PNG\r\n\x1A\n".b)
    end

    it "fails cleanly for a binary file labelled as CSV" do
      png = File.binread(Rails.root.join("spec/fixtures/files/receipt.png"))
      blob = create_blob(png, filename: "receipt.csv", content_type: "text/csv")

      expect { blob.preview(resize_to_limit: [500, 500]).processed }.to raise_error(ActiveStorage::PreviewError)
    end
  end

  it "no longer previews office documents" do
    blob = create_blob(
      "PK\x03\x04".b,
      filename: "memo.docx",
      content_type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    )

    expect(blob).not_to be_previewable
  end
end
