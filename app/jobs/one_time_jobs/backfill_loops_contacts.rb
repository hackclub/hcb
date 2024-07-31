# frozen_string_literal: true

module OneTimeJobs
  class BackfillLoopsContacts < ApplicationJob
    def perform
      queue = Limiter::RateQueue.new(10, interval: 1)
      User.find_each(batch_size: 100) do |user|
        UserService::SyncWithLoops.new(user_id: user.id, queue:).run if user.teenager?
      end
    end

  end
end
