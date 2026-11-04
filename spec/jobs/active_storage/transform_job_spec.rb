# frozen_string_literal: true

require "rails_helper"

RSpec.describe ActiveStorage::TransformJob, type: :job do
  it "discards transforms for legacy empty blobs before invoking the image processor" do
    blob = ActiveStorage::Blob.new(
      filename: "empty.png",
      content_type: "image/png",
      byte_size: 0,
      checksum: OpenSSL::Digest::MD5.base64digest(""),
      service_name: ActiveStorage::Blob.service.name
    )
    # Simulate a blob created before zero-byte validation was added.
    blob.save!(validate: false)

    allow(Rails.error).to receive(:report)
    expect(blob).not_to receive(:representation)

    expect { described_class.perform_now(blob, resize_to_limit: [1024, 1024]) }.not_to raise_error
    expect(Rails.error).to have_received(:report).with(
      instance_of(ActiveStorage::UnrepresentableError),
      handled: true,
      context: {
        active_storage_blob_id: blob.id,
        transformations: { resize_to_limit: [1024, 1024] }
      }
    )
  end
end
