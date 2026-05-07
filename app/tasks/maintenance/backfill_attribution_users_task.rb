# frozen_string_literal: true

module Maintenance
  class BackfillAttributionUsersTask < MaintenanceTasks::Task
    def collection
      Referral::Attribution.where.not(user_session: nil).where(user: nil)
    end

    def process(attribution)
      attribution.update!(user: attribution.user_session.user)
    end

  end
end
