# frozen_string_literal: true

module Maintenance
  class BackfillReferralAttributionUsersTask < MaintenanceTasks::Task
    # Sets Referral::Attribution#user_id from the bound user on the
    # attribution's User::Session, for rows where user_id is nil but the
    # session is already associated with a user. User::Session#user_id is
    # set-once (see User::Session#create_login_activity), so the join is
    # unambiguous.
    def collection
      Referral::Attribution
        .where(user_id: nil)
        .where.not(user_session_id: nil)
        .joins(:user_session)
        .where.not(user_sessions: { user_id: nil })
        .select("referral_attributions.*, user_sessions.user_id AS resolved_user_id")
    end

    def process(attribution)
      attribution.update_columns(user_id: attribution.resolved_user_id, updated_at: Time.current)
    end

  end
end
