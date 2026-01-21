# frozen_string_literal: true

class User
  class Session
    class ClearOldUserSessionsJob < ApplicationJob
      queue_as :low

      def perform
        User::Session.expired.where("created_at < ?", 1.year.ago).find_each(&:clear_metadata!)
      end

    end

  end

end
