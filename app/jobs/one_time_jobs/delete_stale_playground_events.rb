# frozen_string_literal: true

module OneTimeJobs
  class DeleteStalePlaygroundEvents
    def self.perform
      Event.demo_mode.where("created_at < ?", 6.months.ago).destroy_all
    end

  end
end
