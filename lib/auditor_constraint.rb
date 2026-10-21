# frozen_string_literal: true

# Used to restrict access of Sidekiq to admins. See routes.rb for more info.
class AuditorConstraint
  include Rails.application.routes.url_helpers

  def self.matches?(request)
    session_token = request.cookie_jar.encrypted[:session_token]

    return false unless session_token.present?

    potential_session = User::Session.not_expired.find_by(session_token:)
    if potential_session
      return potential_session.user&.auditor?
    end

    false
  end

end
