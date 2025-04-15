# frozen_string_literal: true

class ExportJob < ApplicationJob
  queue_as :default

  def perform(export_id:)
    @export = Export.find(export_id)

    content = @export.content

    ExportMailer.export_ready(
      email: @export.requested_by.email,
      mime_type: @export.mime_type,
      filename: @export.filename,
      label: @export.label,
      content:
    ).deliver_later
  end

end
