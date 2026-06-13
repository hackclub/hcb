# frozen_string_literal: true

module Maintenance
  class BackfillOpiOwnersTask < MaintenanceTasks::Task
    def collection
      OrganizerPositionInvite.where(is_signee: true)
    end

    def process(opi)
      opi.update!(role: :owner)
    end

  end
end
