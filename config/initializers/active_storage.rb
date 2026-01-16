# frozen_string_literal: true

Rails.application.config.to_prepare do
  ActiveStorage::PreviewImageJob.discard_on ActiveStorage::PreviewError
end

Rails.application.configure do
  # Whatever is added to variable_content_types but is also not in config.active_storage.web_image_content_types
  # will be auto-converted to png by ActiveStorage
  config.active_storage.variable_content_types << "image/heic"
  config.active_storage.variable_content_types << "image/webp"
end
