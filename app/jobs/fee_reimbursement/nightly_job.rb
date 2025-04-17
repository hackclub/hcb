# frozen_string_literal: true

class FeeReimbursement
  class NightlyJob < ApplicationJob
    queue_as :low
    def perform
      FeeReimbursementService::Nightly.new.run
    end

  end

end

module FeeReimbursementJob
  Nightly = FeeReimbursement::NightlyJob
end
