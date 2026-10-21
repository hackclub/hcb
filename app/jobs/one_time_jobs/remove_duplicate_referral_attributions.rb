# frozen_string_literal: true

module OneTimeJobs
  class RemoveDuplicateReferralAttributions < ApplicationJob
    def perform
      duplicates = Referral::Attribution
                   .select(:user_id, :referral_program_id)
                   .group(:user_id, :referral_program_id)
                   .having("COUNT(*) > 1")

      duplicates.each do |dup|
        Referral::Attribution
          .where(user_id: dup.user_id, referral_program_id: dup.referral_program_id)
          .order(created_at: :asc)
          .offset(1)
          .destroy_all
      end
    end

  end
end
