# frozen_string_literal: true

module Maintenance
  # Fills `user_sessions.user_agent` for sessions created before it was
  # recorded, from the Login::Attempt that completed the session's login.
  #
  # LoginsController#complete creates the session in the same request that
  # satisfies the login's final factor, so when that factor was the email
  # code, the succeeded email attempt holds the exact User-Agent header of the
  # request that built the session. The login's PaperTrail version that moved
  # it to `complete` shows which factor did it. Sessions whose login finished
  # on another factor are left alone: the browser-token cookie makes it the
  # same browser, but not provably the same header.
  class BackfillSessionUserAgentTask < MaintenanceTasks::Task
    # Matches Login::Attempt::ClearOldAttemptsJob and
    # User::Session::ClearOldUserSessionsJob, which scrub both after this long.
    RETENTION = 18.months

    def collection
      User::Session
        .where(user_agent: nil)
        .where(created_at: RETENTION.ago..)
        .where(id: Login.where(id: Login::Attempt.email.succeeded.select(:login_id)).select(:user_session_id))
    end

    def process(session)
      logins = session.logins.where(is_reauthentication: false).to_a
      return unless logins.one?

      login = logins.first
      attempts = login.attempts.email.succeeded.to_a
      return unless attempts.one?

      attempt = attempts.first
      return if attempt.user_agent.blank?

      completion = login.versions.where_object_changes_to(aasm_state: "complete").last
      before, after = completion&.object_changes&.dig("authentication_factors")
      return unless after.to_h.key?("email") && !before.to_h.key?("email")

      session.update_columns(user_agent: attempt.user_agent)
    end

  end
end
