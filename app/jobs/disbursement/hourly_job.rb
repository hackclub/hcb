# frozen_string_literal: true

class Disbursement
  class HourlyJob < ApplicationJob
    queue_as :low
    def perform
      DisbursementService::Hourly.new.run
    end

  end

end

module DisbursementJob
  Hourly = Disbursement::HourlyJob
end
