# frozen_string_literal: true

class UserSession
  class ExpirationJob < ApplicationJob
    queue_as :low

    def perform
      UserSession.joins(:user)
                 .where("user_sessions.last_seen_at + (users.session_validity_preference * interval '1 minute') < NOW()")
                 .find_each do |session|
        session.set_as_peacefully_expired
        session.destroy
      end
    end

  end

end