# frozen_string_literal: true

module OneTimeJobs
  class BackfillVerifiedOnUser < ApplicationJob
    def perform
      User.update(verified: true)
    end

  end

end
