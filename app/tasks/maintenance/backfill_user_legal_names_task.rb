# frozen_string_literal: true

module Maintenance
  class BackfillUserLegalNamesTask < MaintenanceTasks::Task
    def collection
      User.where(legal_first_name: nil).where.not(full_name: [nil, ""])
    end

    def process(user)
      parsed = UserService::ParseName.new(full_name: user.full_name).run

      # Scoped to still-unsplit rows so a name the user saved in the meantime is never overwritten.
      User.where(id: user.id, legal_first_name: nil, full_name: user.full_name)
          .update_all(legal_first_name: parsed.first_name, legal_last_name: parsed.last_name)
    end

  end
end
