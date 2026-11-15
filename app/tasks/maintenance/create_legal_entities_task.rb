# frozen_string_literal: true

module Maintenance
  class CreateLegalEntitiesTask < MaintenanceTasks::Task
    def collection
      User.where.missing(:legal_entities)
    end

    def process(user)
      user.send :create_legal_entity
    end

  end
end
