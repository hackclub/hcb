# frozen_string_literal: true

ActiveSupport.on_load(:active_storage_blob) do
  validates :byte_size, numericality: { greater_than: 0 }
end

Rails.application.config.to_prepare do
  ActiveStorage::PreviewImageJob.discard_on ActiveStorage::PreviewError
end

Rails.application.config.after_initialize do
  ActiveStorage::TransformJob.before_perform do |job|
    blob, transformations = job.arguments
    next unless blob.byte_size.zero?

    # Active Storage discards this error instead of allowing it to reach Sidekiq:
    # https://github.com/rails/rails/blob/v8.1.3.1/activestorage/app/jobs/active_storage/transform_job.rb#L3-L7
    error = ActiveStorage::UnrepresentableError.new("Cannot transform an empty blob")
    Rails.error.report(
      error,
      handled: true,
      context: { active_storage_blob_id: blob.id, transformations: }
    )
    raise error
  end
end

Rails.application.configure do
  # Whatever is added to variable_content_types but is also not in config.active_storage.web_image_content_types
  # will be auto-converted to png by ActiveStorage
  config.active_storage.variable_content_types << "image/heic"
  config.active_storage.variable_content_types << "image/webp"
end
