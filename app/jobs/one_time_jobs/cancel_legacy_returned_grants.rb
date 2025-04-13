# frozen_string_literal: true

module OneTimeJobs
  class CancelLegacyReturnedGrants
    def self.perform()
      CardGrant.where(status: :canceled).or(CardGrant.where(status: :expired)).find_each do |card_grant|
        @card = StripeCard.find(card_grant.stripe_card_id)
        if !@card.canceled?
          @card.cancel!
        end
      end
    end
  end
end
