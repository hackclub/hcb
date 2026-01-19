# frozen_string_literal: true

class StripeCard
  class ExpirationJob < ApplicationJob
    queue_as :low
    def perform
      StripeCard.active.or(StripeCard.frozen).find_each do |sc|
        if Date.current > Date.new(sc.exp_year, sc.exp_month, 1).end_of_month
          sc.cancel!
        end
      end
    end

  end

end
