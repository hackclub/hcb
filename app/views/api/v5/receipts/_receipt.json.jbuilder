# frozen_string_literal: true

# locals: (json:, receipt:)

object_shape(json, receipt) do |f|
  f.url { receipt.url }
  f.preview_url { receipt.preview(only_path: false) }
  f.filename { receipt.file.blob.filename }

  f.nest(:uploader) do
    if receipt.user.present?
      json.partial! "api/v5/users/user", user: receipt.user
    else
      json.nil!
    end
  end
end
