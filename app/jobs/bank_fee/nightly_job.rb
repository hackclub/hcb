# frozen_string_literal: true

class BankFee
  class NightlyJob < ApplicationJob
    queue_as :low
    def perform
      BankFeeService::Nightly.new.run
    end

  end

end

module BankFeeJob
  Nightly = BankFee::NightlyJob
end
