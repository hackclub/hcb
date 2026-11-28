# frozen_string_literal: true

class ExportMailer < ApplicationMailer
  def export_ready(export:)
    @export = export

    mail to: @export.requested_by.email, subject: "Your export is ready!"
  end

end
