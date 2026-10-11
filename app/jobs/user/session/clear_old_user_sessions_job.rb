# frozen_string_literal: true

class User
  class Session
    class ClearOldUserSessionsJob < ApplicationJob
      queue_as :low

      def perform
        User::Session.expired.where("created_at < ?", 18.months.ago).find_each(&:clear_ip_metadata!)
      end

    end

  end

end
