# frozen_string_literal: true

class CardGrant
  class ExpirationJob < ApplicationJob
    queue_as :low
    def perform
      CardGrant.joins(:card_grant_setting).active.where("card_grants.created_at + (card_grant_settings.expiration_preference * interval '1 day') < NOW()").find_each do |card_grant|
        card_grant.expire!
      end
    end

  end

end
