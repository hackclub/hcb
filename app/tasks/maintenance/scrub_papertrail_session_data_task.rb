# frozen_string_literal: true

module Maintenance
  class ScrubPapertrailSessionDataTask < MaintenanceTasks::Task
    COLUMNS = ["ip", "latitude", "longitude"].freeze

    def collection
      PaperTrail::Version.where(item_type: "User::Session")
    end

    def process(version)
      changes = {}

      if version.object.present?
        object = version.object

        COLUMNS.each do |column|
          if object.key?(column)
            object.delete(column)
            changes[:object] = object
          end
        end
      end

      if version.object_changes.present?
        object_changes = version.object_changes

        COLUMNS.each do |column|
          if object_changes.key?(column)
            object_changes.delete(column)
            changes[:object_changes] = object_changes
          end
        end
      end

      version.update!(changes) if changes.any?
    end

  end
end
