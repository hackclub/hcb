# frozen_string_literal: true

module OneTimeJobs
  class BackfillJoinedAsTeenager < ApplicationJob
    def perform
      User.find_each do |user|
        user.update!(joined_as_teenager: user.was_teenager_on_join?)
      end
    end

  end

end
