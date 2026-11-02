# frozen_string_literal: true

class Login
  class Attempt
    class ClearOldAttemptsJob < ApplicationJob
      queue_as :low

      def perform
        Login::Attempt
          .where.not(ip_address: nil).or(Login::Attempt.where.not(user_agent: nil))
          .where("created_at < ?", 18.months.ago)
          .find_each(&:clear_ip_metadata!)
      end

    end

  end

end
