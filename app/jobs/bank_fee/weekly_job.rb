# frozen_string_literal: true

class BankFee
  class WeeklyJob < ApplicationJob
    queue_as :low
    def perform
      BankFeeService::Weekly.new.run
    end

  end

end

module BankFeeJob
  Weekly = BankFee::WeeklyJob
end
