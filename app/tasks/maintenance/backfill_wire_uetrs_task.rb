# frozen_string_literal: true

module Maintenance
  class BackfillWireUetrsTask < MaintenanceTasks::Task
    def collection
      Wire.where(uetr: nil).where.not(column_id: nil)
    end

    def process(wire)
      uetr = wire.column_wire_details["uetr"]
      wire.update!(uetr:) if uetr.present?
    end

  end
end
