# frozen_string_literal: true

require "rails_helper"

RSpec.describe HasAttachments do
  let(:mailbox) do
    Class.new do
      include HasAttachments
      attr_reader :mail

      def initialize(mail) = @mail = mail
      def run = set_attachments
      def html = mail.html_part&.body&.decoded
      def text = mail.text_part&.body&.decoded
      def body = mail.body&.decoded&.presence
    end
  end

  it "embeds inline cid: images before rendering the email body" do
    logo = File.binread(Rails.root.join("public/logo.png"))
    mail = Mail.new do
      html_part { content_type "text/html; charset=UTF-8"; body '<img src="cid:logo123">' }
    end
    mail.attachments.inline["logo.png"] = { content: logo, mime_type: "image/png", content_id: "<logo123>" }

    expect(CloudflareBrowserRun).to receive(:pdf)
      .with(%(<img src="data:image/png;base64,#{Base64.strict_encode64(logo)}">))
      .and_return("%PDF-1.4")

    attachments = mailbox.new(Mail.read_from_string(mail.to_s)).run

    expect(attachments.map { |a| a[:content_type] }).to eq(["application/pdf"])
  end
end
