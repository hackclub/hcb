# frozen_string_literal: true

module OneTimeJobs
  class BackfillGrantExpiration
    def self.perform
      CardGrant.find_each do |cg|
        cg.update(expiration_at: cg.created_at + (CardGrantSetting.expiration_preferences[cg.event.card_grant_setting.expiration_preference].days))
      end
    end

  end
end
