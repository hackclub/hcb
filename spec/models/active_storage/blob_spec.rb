# frozen_string_literal: true

require "rails_helper"

RSpec.describe ActiveStorage::Blob, type: :model do
  it "rejects an empty file" do
    blob = described_class.build_after_unfurling(
      io: StringIO.new,
      filename: "empty.png",
      content_type: "image/png"
    )

    expect(blob).not_to be_valid
    expect(blob.errors.of_kind?(:byte_size, :greater_than)).to be(true)
  end

  it "does not preview office documents or CSVs" do
    {
      "report.doc"  => "application/msword",
      "report.docx" => "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
      "slides.ppt"  => "application/vnd.ms-powerpoint",
      "slides.pptx" => "application/vnd.openxmlformats-officedocument.presentationml.presentation",
      "sheet.xls"   => "application/vnd.ms-excel",
      "sheet.xlsx"  => "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      "receipt.csv" => "text/csv",
    }.each do |filename, content_type|
      blob = described_class.new(filename:, content_type:)

      expect(blob).not_to be_previewable, "expected #{filename} not to be previewable"
    end
  end
end
