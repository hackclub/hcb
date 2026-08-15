# frozen_string_literal: true

# Cloudflare Turnstile — a bot check in front of the flows that dispatch a
# Twilio Verify SMS. Each SMS costs us money and lands on someone's phone, so
# these are the flows spam signups have historically abused.
#
# The server half lives in TurnstileService::Verify; the widget is rendered by
# the `application/turnstile` partial and the `turnstile` Stimulus controller.
module TurnstileService
  # Widget actions. Cloudflare records these when a token is solved and echoes
  # them back at siteverify, so a token minted on one form can't be replayed
  # against another. Referenced by both the view and the controller to keep the
  # two from drifting apart.
  LOGIN_ACTION = "login"
  SMS_VERIFICATION_ACTION = "sms-verification"

  def self.site_key
    Credentials.fetch(:TURNSTILE, :SITE_KEY)
  end

  def self.secret_key
    Credentials.fetch(:TURNSTILE, :SECRET_KEY)
  end

  # Turnstile is skipped wholesale when it isn't configured, so development,
  # test, and any deploy without the credentials keep working. Once both keys
  # are present the check is mandatory and fails closed.
  def self.enabled?
    site_key.present? && secret_key.present?
  end
end
