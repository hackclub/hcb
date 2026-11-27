# frozen_string_literal: true

class MailboxMailer < ApplicationMailer
  internal!

  def forward(inbound_email:, to:)
    mail to:, reply_to: inbound_email.mail.from,
         content_type: "text/html",
         subject: "Fwd: #{inbound_email.mail.subject} (#{inbound_email.mail.to.first})",
         body: inbound_email.mail.body.decoded
  end

end
