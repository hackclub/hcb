# frozen_string_literal: true

module OneTimeJobs
  class BackfillGrantExpiration
    def self.perform
      CardGrant.find_each do |cg|
        cg.update(expiration_date: cg.created_at + (cg.event.card_grant_setting&.expiration_preference_before_type_cast&.days || 365.days))
      end
    end

  end
end
