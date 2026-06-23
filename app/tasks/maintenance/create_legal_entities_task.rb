# frozen_string_literal: true

module Maintenance
  class CreateLegalEntitiesTask < MaintenanceTasks::Task
    def collection
      User.where(legal_entity_id: nil)
    end

    def process(user)
      le = LegalEntity.create!
      user.update!(legal_entity: le)
    end

  end
end
