# frozen_string_literal: true

# Used to restrict access of Sidekiq to admins. See routes.rb for more info.
class AdminConstraint
  include Rails.application.routes.url_helpers

  def self.matches?(request)
    session_token = request.cookie_jar.encrypted[:session_token]

    return false unless session_token.present?

    potential_session = User::Session.not_expired.find_by(session_token:)
    if potential_session
      return potential_session.user&.admin?
    end

    false
  rescue NoMethodError
    # `request.cookie_jar` can be backed by a request that never went through
    # the ActionDispatch::Cookies middleware (e.g. a synthetic request built by
    # `ActionDispatch::Routing::RouteSet#recognize_path`), in which case
    # `request.key_generator` is nil and cookie decryption blows up. Fail
    # closed (deny access) rather than raising a 500.
    false
  end

end
