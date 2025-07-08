# frozen_string_literal: true

class UserSession
  class ClearOldUserSessionsJob < ApplicationJob
    queue_as :low

    def perform
      UserSession.where("created_at < ?", 1.year.ago).find_each do |session|
        session.update_columns(
          device_info: nil,
          latitude: nil,
          longitude: nil
        )
      end
    end

  end

end
