# frozen_string_literal: true

require_relative "session_cookie_support"

module RequestSessionSupport
  include SessionCookieSupport

  # Signs in for a request spec by sending `user_session`'s token in the
  # encrypted session cookie, the same way a browser would. Requests then go
  # through the real `SessionsHelper#find_current_session`, so expiry and
  # cookie handling are exercised rather than stubbed out.
  #
  # Unlike `SystemSessionSupport#sign_in(user)`, this takes a session so specs
  # can sign in with an unverified or impersonation session.
  #
  # @param user_session [User::Session]
  # @return [User::Session]
  def sign_in_with(user_session)
    # rack-test escapes cookie values itself, unlike Cuprite's `set_cookie`.
    cookies[:session_token] = encrypted_session_cookie(user_session)

    user_session
  end
end

RSpec.configure do |config|
  config.include RequestSessionSupport, type: :request
end
