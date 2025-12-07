# frozen_string_literal: true

module OneTimeJobs
  class MigrateReferralProgramsToLinks < ApplicationJob
    def perform
      Referral::Program.find_each do |program|
        Referral::Link.create!(
          program:,
          slug: program.hashid,
          creator: program.creator,
          name: "Default link (backfilled from program)"
        )
      end
    end

  end
end
