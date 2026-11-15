# frozen_string_literal: true

module LogoHelper
  HCB_LOGO_BLOB_KEY = "hcb-email-logo"

  # Returns a URL for the HCB logo resized to the specified height using Active Storage variants.
  def hcb_logo_variant_url(height: 80)
    blob = find_or_create_hcb_logo_blob
    variant = blob.variant(resize_to_limit: [nil, height])
    Rails.application.routes.url_helpers.url_for(variant)
  end

  private

  def find_or_create_hcb_logo_blob
    ActiveStorage::Blob.find_by(key: HCB_LOGO_BLOB_KEY) || create_hcb_logo_blob
  end

  def create_hcb_logo_blob
    logo_path = Rails.root.join("public/brand/hcb-icon-icon-original.png")

    ActiveStorage::Blob.create_and_upload!(
      key: HCB_LOGO_BLOB_KEY,
      io: File.open(logo_path),
      filename: "hcb-icon-icon-original.png",
      content_type: "image/png"
    )
  end
end
