# frozen_string_literal: true

module Payroll
  class Position
    class ExpireNightlyJob < ApplicationJob
      queue_as :low

      def perform
        Payroll::Position.onboarded.where(end_date: ...Date.current).find_each do |position|
          Payroll::Position::ExpireJob.perform_later(position)
        end
      end

    end

  end

end
