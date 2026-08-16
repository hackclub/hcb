# frozen_string_literal: true

# Cloudflare Turnstile — a bot check in front of phone-number verification,
# the one flow that texts a Twilio Verify code to an unverified, user-typed
# number. That's the surface spam signups have abused to run up our Twilio
# bill; login SMS codes only ever go to numbers verified through here.
#
# The server half lives in TurnstileService::Verify; the widget is rendered by
# the `settings/SmsVerification` React component via `common/turnstile.js`.
module TurnstileService
  # Widget action. Cloudflare records it when a token is solved and echoes it
  # back at siteverify, so a token minted by any other widget on our sitekey
  # can't be replayed here. Referenced by both the component and the controller
  # to keep the two from drifting apart.
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
