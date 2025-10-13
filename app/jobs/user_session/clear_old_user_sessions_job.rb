# frozen_string_literal: true

class UserSession
  class ClearOldUserSessionsJob < ApplicationJob
    queue_as :low

    def perform
      UserSession.expired.where("created_at < ?", 1.year.ago).find_each(&:clear_metadata!)
    end

  end

end
