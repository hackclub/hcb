# frozen_string_literal: true

# An Action Mailer delivery method that writes each email to the Rails log
# instead of sending it. Useful for non-production deploys without SMTP
# (e.g. Laravel Cloud staging), where you still need to read login codes.
#
# Enable with `config.action_mailer.delivery_method = :log`.
class LogMailDelivery
  def initialize(settings = {})
    @settings = settings
  end

  def deliver!(mail)
    Rails.logger.info(<<~LOG)
      [LogMailDelivery] Email not sent (delivery_method :log)
        To: #{Array(mail.to).join(", ")}
        Subject: #{mail.subject}
      #{body_text(mail)}
    LOG
  end

  private

  def body_text(mail)
    if mail.text_part
      mail.text_part.decoded
    elsif mail.html_part || mail.mime_type == "text/html"
      doc = Nokogiri::HTML((mail.html_part || mail).decoded)
      doc.css("style, script, head").each(&:remove)
      doc.css("p, div, br, li, tr, h1, h2, h3, h4, h5, h6").each { |node| node.after("\n") }
      doc.text.gsub(/[ \t]+/, " ").gsub(/\n\s*\n+/, "\n").strip
    else
      mail.body.decoded
    end
  end

end
