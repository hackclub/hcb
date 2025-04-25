# frozen_string_literal: true

class Donation
  class NightlyJob < ApplicationJob
    queue_as :low
    def perform
      DonationService::Nightly.new.run
    end

  end

end

module DonationJob
  Nightly = Donation::NightlyJob
end
