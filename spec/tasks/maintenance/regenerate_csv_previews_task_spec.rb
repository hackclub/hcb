# frozen_string_literal: true

require "rails_helper"

RSpec.describe Maintenance::RegenerateCsvPreviewsTask do
  def create_blob(content, filename:, content_type:)
    ActiveStorage::Blob.create_and_upload!(io: StringIO.new(content), filename:, content_type:, identify: false)
  end

  # A preview cached before the switch to csv_preview: any image, not drawn by csv_preview.
  def cache_old_preview(blob)
    blob.preview_image.attach(io: File.open(Rails.root.join("spec/fixtures/files/receipt.png")), filename: "old.png", content_type: "image/png")
    blob.preview_image.blob
  end

  let(:csv) { create_blob("Merchant,Amount\nHack Club,12.34\n", filename: "receipt.csv", content_type: "text/csv") }

  describe ".collection" do
    it "only collects CSV blobs with a cached preview" do
      cache_old_preview(csv)
      create_blob("Merchant,Amount\n", filename: "fresh.csv", content_type: "text/csv")
      pdf = create_blob("%PDF-1.4", filename: "receipt.pdf", content_type: "application/pdf")
      cache_old_preview(pdf)

      expect(described_class.collection).to contain_exactly(csv)
    end
  end

  describe ".process" do
    before do
      # CI installs libvips, so a missing install fails there instead of skipping.
      skip "libvips with Pango is not installed" unless CsvPreview.text_supported? || ENV["CI"]
    end

    it "replaces the cached preview with one drawn by csv_preview and purges the old one" do
      old_preview = cache_old_preview(csv)

      expect { described_class.process(csv) }.to have_enqueued_job(ActiveStorage::PurgeJob).with(old_preview)

      new_preview = csv.reload.preview_image.blob
      expect(new_preview).not_to eq(old_preview)
      expect(new_preview.content_type).to eq("image/png")
      expect(new_preview.download.byteslice(0, 8)).to eq("\x89PNG\r\n\x1A\n".b)
    end

    it "draws the 1024x1024 variant a receipt's preview uses" do
      receipt = Receipt.new(receiptable: create(:hcb_code), upload_method: :api)
      receipt.file.attach(io: StringIO.new("Merchant,Amount\nHack Club,12.34\n"), filename: "receipt.csv", content_type: "text/csv")
      receipt.save!
      cache_old_preview(receipt.file.blob)

      described_class.process(receipt.file.blob)

      preview_image = receipt.file.blob.reload.preview_image
      expect(preview_image.blob.variant_records.map(&:variation_digest))
        .to contain_exactly(preview_image.variant(resize: "1024x1024").variation.digest)
    end

    it "keeps the cached preview of a file that isn't really a CSV and reports the error" do
      junk = create_blob(File.binread(Rails.root.join("spec/fixtures/files/receipt.png")), filename: "receipt.csv", content_type: "text/csv")
      old_preview = cache_old_preview(junk)
      expect(Rails.error).to receive(:report).with(instance_of(ActiveStorage::PreviewError), hash_including(handled: true, context: { active_storage_blob_id: junk.id }))

      expect { described_class.process(junk) }.not_to raise_error

      expect(junk.reload.preview_image.blob).to eq(old_preview)
    end
  end
end
