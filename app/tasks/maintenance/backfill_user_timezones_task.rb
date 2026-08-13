# frozen_string_literal: true

module Maintenance
  # Seeds the timezone preference from the guess we can already make off a user's
  # sessions, so most people find it already pointing somewhere sensible.
  #
  # Users we cannot infer a timezone for are left NULL rather than written with
  # the default, otherwise "we guessed Eastern" would become indistinguishable
  # from "this user chose Eastern".
  class BackfillUserTimezonesTask < MaintenanceTasks::Task
    def collection
      User.where(timezone: nil)
          .where(id: User::Session.where.not(timezone: [nil, ""]).select(:user_id))
    end

    def process(user)
      selectable = User.selectable_timezone_name(user.inferred_timezone)
      return if selectable.nil?

      user.update!(timezone: selectable)
    end

  end
end
