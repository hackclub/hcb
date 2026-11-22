# frozen_string_literal: true

module Maintenance
  # Redraws every cached CSV preview. CSV previews used to be drawn by
  # LibreOffice (removed in hackclub/hcb-private#369) and are now drawn by
  # csv_preview (hackclub/hcb-private#357), but Active Storage caches a blob's
  # preview image as its preview_image attachment and never redraws it, so
  # every CSV previewed before the switch still shows the LibreOffice image.
  #
  # Only blobs with a cached preview are touched. CSVs that were never
  # previewed are drawn lazily the first time someone views them, as before.
  # Run once after deploying #357.
  class RegenerateCsvPreviewsTask < MaintenanceTasks::Task
    def collection
      ActiveStorage::Blob.where(content_type: "text/csv").joins(:preview_image_attachment)
    end

    def process(blob)
      # Only the libvips-less case gets here (csv_preview accepts every text/csv blob), and
      # that's a problem with the process running the task, so halt rather than skip blobs.
      previewer = ActiveStorage.previewers.detect { |klass| klass.accept?(blob) }
      raise ActiveStorage::UnpreviewableError, "No previewer accepts blob #{blob.id}" unless previewer

      # Attaching replaces the cached image, which Active Storage then purges, so a blob whose
      # file isn't really a CSV (ActiveStorage::PreviewError) keeps the preview it had.
      previewer.new(blob).preview(service_name: blob.service_name) do |attachable|
        blob.preview_image.attach(attachable)
      end

      # Receipt#preview requests the 1024x1024 variant, which uploads preprocess (see
      # Receipt::PREPROCESSED_SIZES). Draw it now so the first view after the switch isn't slow.
      blob.preview(resize: "1024x1024").processed if blob.attachments.exists?(record_type: "Receipt")
    rescue ActiveStorage::PreviewError => e
      Rails.error.report(e, handled: true, context: { active_storage_blob_id: blob.id })
    end

  end
end
