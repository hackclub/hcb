# frozen_string_literal: true

# Cloudflare Turnstile — a bot check in front of the two unauthenticated flows
# that cost us money when scripted:
#
#   * phone-number verification, which texts a Twilio Verify code to an
#     unverified, user-typed number (login SMS codes only ever go to numbers
#     verified through here);
#   * starting a donation, which mints a Stripe PaymentIntent that a card
#     tester can then throw stolen numbers at.
#
# The server half lives in TurnstileService::Verify; widgets are rendered by
# the `settings/SmsVerification` React component and the `turnstile` Stimulus
# controller, both via `common/turnstile.js`.
module TurnstileService
  # Widget action. Cloudflare records it when a token is solved and echoes it
  # back at siteverify, so a token minted by any other widget on our sitekey
  # can't be replayed here. Referenced by both the component and the controller
  # to keep the two from drifting apart.
  SMS_VERIFICATION_ACTION = "sms-verification"

  # Shared by the one-time and monthly donation forms: they're the same widget
  # on the same page, and both land on a controller that creates Stripe
  # objects.
  DONATION_ACTION = "donation"

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
