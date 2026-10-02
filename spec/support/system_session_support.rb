# frozen_string_literal: true

module SystemSessionSupport
  include UserSessionSupport

  # Signs the browser in with the same encrypted session cookie a real login sets.
  #
  # @param user [User]
  # @return [User::Session]
  def sign_in(user)
    user_session = create_user_session(user, verified: true)
    jar = ActionDispatch::TestRequest.create.cookie_jar
    jar.encrypted[:session_token] = user_session.session_token
    page.driver.set_cookie("session_token", Rack::Utils.escape(jar[:session_token]), domain: Capybara.server_host)
    user_session
  end
end
