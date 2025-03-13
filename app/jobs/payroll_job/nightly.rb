# frozen_string_literal: true

module PayrollJob
  class Nightly < ApplicationJob
    queue_as :low
    def perform
      PayrollService::Nightly.new.run
    end

  end
end
