# frozen_string_literal: true

class ExportMailer < ApplicationMailer
  def export_ready(label:, email:, mime_type:, filename:, content:)
    @mime_type = mime_type
    @filename = filename
    @content = content
    @email = email
    @label = label
    # Once file sizes become large, we'll need to upload to S3 and provide a
    # download link. However, we are not at that point just yet.
    attachments[@filename] = { mime_type:, content: }

    mail to: @email, subject: "Your export is ready!"
  end

end
