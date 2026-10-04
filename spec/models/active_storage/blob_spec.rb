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
end
