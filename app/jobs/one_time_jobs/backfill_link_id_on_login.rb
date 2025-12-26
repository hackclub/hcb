# frozen_string_literal: true

module OneTimeJobs
  class BackfillLinkIdOnLogin < ApplicationJob
    def perform
      Login.where.not(referral_program_id: nil).find_each do |login|
        login.update!(referral_link_id: login.referral_program.links.first.id)
      end
    end

  end

end
