# frozen_string_literal: true

module OneTimeJobs
  class MigrateReferralProgramsToLinks < ApplicationJob
    def perform
      Referral::Program.find_each do |program|
        link = Referral::Link.create!(
          program:,
          slug: program.hashid,
          creator: program.creator,
          name: "Default link (backfilled from program)"
        )

        program.attributions.update_all(referral_link_id: link.id)
      end
    end

  end
end
