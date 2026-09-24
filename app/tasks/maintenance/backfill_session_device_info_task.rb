# frozen_string_literal: true

module Maintenance
  class BackfillSessionDeviceInfoTask < MaintenanceTasks::Task
    def collection
      User::Session.where(device_info: nil)
    end

    def process(session)
      version_with_device_info = session.versions.where_object_changes_to(device_info: nil).last

      return if version_with_device_info.nil?

      session.update!(device_info: version_with_device_info.object["device_info"])
    end

  end
end
