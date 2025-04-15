# frozen_string_literal: true

class Disbursement
  class NightlyJob < ApplicationJob
    queue_as :low
    def perform
      DisbursementService::Nightly.new.run
    end

  end

end

module DisbursementJob
  Nightly = Disbursement::NightlyJob
end
