# frozen_string_literal: true

class UserSession
  class ClearOldUserSessionsJob < ApplicationJob
    queue_as :low

    def perform
      UserSession.where("created_at < ?", 1.year.ago).find_each do |session|
        session.update_columns(
          device_info: nil,
          os_info: nil,
          timezone: nil,
          ip: nil,
          impersonated_by_id: nil,
          latitude: nil,
          longitude: nil
        )
      end
    end

  end

end
