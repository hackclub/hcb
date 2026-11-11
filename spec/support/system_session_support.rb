# frozen_string_literal: true

module SystemSessionSupport
  # Signs `user` in for a system spec by setting the encrypted session cookie
  # in the browser, skipping the login flow.
  #
  # @param user [User]
  # @return [User::Session]
  def sign_in(user, verified: true)
    user_session = create(:user_session, user:, expiration_at: 1.day.from_now, verified:)

    jar = ActionDispatch::Request.new(Rails.application.env_config).cookie_jar
    jar.encrypted[:session_token] = user_session.session_token

    # The browser only accepts cookies for a host it has already visited.
    visit auth_users_path
    page.driver.set_cookie("session_token", jar[:session_token])

    user_session
  end

  # Pages with a phone field load intl-tel-input from a CDN, which the system
  # spec driver blocks. Stand in for it so phone_input.js doesn't throw on load.
  # Call before the first `visit`.
  def stub_intl_tel_input
    page.driver.browser.evaluate_on_new_document(<<~JS)
      window.intlTelInput = () => ({ getNumber: () => "" })
    JS
  end
end

RSpec.configure do |config|
  config.include SystemSessionSupport, type: :system
end
