# frozen_string_literal: true

ActiveSupport.on_load(:active_storage_blob) do
  validates :byte_size, numericality: { greater_than: 0 }
end

Rails.application.config.to_prepare do
  ActiveStorage::PreviewImageJob.discard_on ActiveStorage::PreviewError
end

Rails.application.configure do
  # Whatever is added to variable_content_types but is also not in config.active_storage.web_image_content_types
  # will be auto-converted to png by ActiveStorage
  config.active_storage.variable_content_types << "image/heic"
  config.active_storage.variable_content_types << "image/webp"
end
