# frozen_string_literal: true

# Requires a solved Cloudflare Turnstile challenge on the actions that dispatch
# a Twilio Verify SMS. Shaped like `invisible_captcha` so the two read alike on
# the controllers where they sit side by side.
#
#   turnstile_protect only: [:start_sms_auth_verification],
#                     action: TurnstileService::SMS_VERIFICATION_ACTION
#
# Clients supply the token in a `cf-turnstile-response` param whose widget was
# rendered with a matching `action` (see `settings/SmsVerification`).
module TurnstileProtection
  extend ActiveSupport::Concern

  TOKEN_PARAM = :"cf-turnstile-response"

  FAILURE_MESSAGE = "We couldn't verify that you're human. Please try again."

  class_methods do
    # `action` is the widget action to require; every other option is passed
    # through to `before_action` (`only:`, `if:`, and so on).
    def turnstile_protect(action:, **options)
      before_action(**options) { verify_turnstile!(action:) }
    end
  end

  private

  def verify_turnstile!(action:)
    return true unless TurnstileService.enabled?

    verified = TurnstileService::Verify.new(
      token: params[TOKEN_PARAM],
      action:,
      hostname: request.host,
      remote_ip: request.remote_ip
    ).run

    return true if verified

    turnstile_failed
    false
  end

  # Override in controllers that have a better place to send someone back to.
  def turnstile_failed
    if request.format.json?
      render json: { error: FAILURE_MESSAGE }, status: :forbidden
    else
      redirect_back fallback_location: root_path, flash: { error: FAILURE_MESSAGE }
    end
  end

end
