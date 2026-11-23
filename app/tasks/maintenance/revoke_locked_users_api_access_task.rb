# frozen_string_literal: true

module Maintenance
  # One-time cleanup: `User#lock!` used to revoke only API tokens that were
  # still accessible, so OAuth access tokens that had already expired at lock
  # time kept their refresh tokens and could still mint new access tokens for
  # the locked user. Revokes every outstanding token, authorization code and
  # device code of the users who are locked today, matching what `lock!` does
  # now. Run once after deploying.
  class RevokeLockedUsersApiAccessTask < MaintenanceTasks::Task
    def collection
      User.where.not(locked_at: nil)
    end

    def process(user)
      user.revoke_api_access!
    end

  end
end
