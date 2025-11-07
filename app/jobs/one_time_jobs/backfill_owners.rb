# frozen_string_literal: true

module OneTimeJobs
  class BackfillOwners
    def self.perform
      OrganizerPosition.find_each do |op|
        if op.is_signee
          op.update!(role: :owner)
        end
      end

      OrganizerPositionInvite.find_each do |opi|
        if opi.is_signee && !opi.event&.users&.pluck(:email)&.include?(opi.user.email)
          opi.update!(role: :owner)
        end
      end
    end

  end
end
