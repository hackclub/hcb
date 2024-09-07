# frozen_string_literal: true

module OneTimeJobs
  class BackfillLoopsContacts < ApplicationJob
    def perform
      queue = Limiter::RateQueue.new(10, interval: 1)
      counter = 0

      User.find_each(batch_size: 100) do |user|
        UserService::SyncWithLoops.new(user_id: user.id, queue:).run unless user.teenager?
        counter += 1
        puts "Processed #{counter} users (#{Time.now})" if counter % 100 == 0
      end

      puts "Done. Processed #{counter} users (#{Time.now})"
    end

  end
end
