# frozen_string_literal: true

module ValidatesRecipientEmail
  extend ActiveSupport::Concern

  included do
    validates :recipient_email, format: { with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email address" }
    normalizes :recipient_email, with: ->(recipient_email) { recipient_email.strip.downcase }
  end
end
