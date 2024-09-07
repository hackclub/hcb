# frozen_string_literal: true

module OneTimeJobs
  class BackfillStripeCardDesigns
    def self.perform
      Event.all.find_each do |e|
        e.generate_stripe_card_designs
      end
    end

  end
end
