# frozen_string_literal: true

class StripeCard
  class NightlyJob < ApplicationJob
    queue_as :low
    def perform
      ::StripeCardService::Nightly.new.run
    end

  end

end

module StripeCardJob
  Nightly = StripeCard::NightlyJob
end
