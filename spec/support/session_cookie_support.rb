# frozen_string_literal: true

module SessionCookieSupport
  # The `session_token` cookie value a browser would send for `user_session`,
  # encrypted the same way `SessionsHelper` reads it.
  #
  # @param user_session [User::Session]
  # @return [String]
  def encrypted_session_cookie(user_session)
    # `env_config` is memoized and merged into every request's env, so building
    # the jar on it directly would leak this cookie into later specs.
    jar = ActionDispatch::Request.new(Rails.application.env_config.dup).cookie_jar
    jar.encrypted[:session_token] = user_session.session_token
    jar[:session_token]
  end
end
