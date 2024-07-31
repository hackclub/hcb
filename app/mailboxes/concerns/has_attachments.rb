# frozen_string_literal: true

module HasAttachments
  extend ActiveSupport::Concern

  included do
    private

    def set_attachments(include_body: true)
      files = mail.attachments.select { |a| valid_content_type(a.content_type) }.map do |atta|
        {
          io: StringIO.new(atta.decoded),
          content_type: atta.content_type,
          filename: atta.filename,
        }
      end

      return @attachments = files if files.any?

      if (content = html || text || body) && include_body
        @attachments = [{
          io: StringIO.new(WickedPdf.new.pdf_from_string(content, encoding: "UTF-8")),
          content_type: "application/pdf",
          filename: "Email_#{(mail.subject || Time.now.strftime("%Y%m%d%H%M")).gsub(/[^0-9A-Za-z]/, '').slice(0, 30)}.pdf"
        }]
      end
    end

    def bounce_missing_attachments
      bounce_with HcbCodeMailer.with(mail: inbound_email, reply_to: mail.to.first).bounce_missing_attachment
    end

    def valid_content_type(content_type)
      content_type.start_with?("application/pdf") || content_type.start_with?("image")
    end

  end

end
