# frozen_string_literal: true

module Payroll
  class NightlyJob < ApplicationJob
    queue_as :low
    def perform
      PayrollService::Nightly.new.run
    end

  end
end

module PayrollJob
  Nightly = Payroll::NightlyJob
end
