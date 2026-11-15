# frozen_string_literal: true

require_relative "session_cookie_support"

module SystemSessionSupport
  include SessionCookieSupport

  # Signs `user` in for a system spec by setting the encrypted session cookie
  # in the browser, skipping the login flow.
  #
  # @param user [User]
  # @return [User::Session]
  def sign_in(user, verified: true)
    user_session = create(:user_session, user:, expiration_at: 1.day.from_now, verified:)

    # The browser only accepts cookies for a host it has already visited.
    visit auth_users_path
    # Escape it the way a Set-Cookie header would: Rack unescapes cookie values,
    # so a raw `+` in the base64 payload would come back as a space.
    page.driver.set_cookie("session_token", Rack::Utils.escape(encrypted_session_cookie(user_session)))

    user_session
  end

  # Pages with a phone field load intl-tel-input from a CDN, which the system
  # spec driver blocks. Stand in for it so phone_input.js doesn't throw on load.
  # Call before the first `visit`.
  def stub_intl_tel_input
    # Browser#evaluate_on_new_document skips pages that are already open
    page.driver.browser.page.command("Page.addScriptToEvaluateOnNewDocument", source: <<~JS)
      window.intlTelInput = () => ({ getNumber: () => "" })
    JS
  end
end

RSpec.configure do |config|
  config.include SystemSessionSupport, type: :system
end
