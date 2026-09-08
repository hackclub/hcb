# frozen_string_literal: true

module Maintenance
  class BackfillLegalEntityNamesTask < MaintenanceTasks::Task
    def collection
      LegalEntity.person.where(name: nil)
    end

    def process(le)
      le.update!(name: le.users.first.full_name)
    end

  end
end
