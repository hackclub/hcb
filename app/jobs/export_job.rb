# frozen_string_literal: true

class ExportJob < ApplicationJob
  queue_as :default

  def perform(export_id:)
    @export = Export.find(export_id)

    @export.file.attach(
      io: StringIO.new(@export.content),
      filename: @export.filename,
      content_type: @export.mime_type
    )

    ExportMailer.export_ready(export: @export).deliver_later
  end

end
