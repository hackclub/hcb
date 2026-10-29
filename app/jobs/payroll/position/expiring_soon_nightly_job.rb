# frozen_string_literal: true

module Payroll
  class Position
    class ExpiringSoonNightlyJob < ApplicationJob
      queue_as :low

      def perform
        Payroll::Position.onboarded.where(end_date: Payroll::Position::EXPIRING_SOON_NOTICE.from_now.to_date).find_each do |position|
          Payroll::PositionMailer.with(position:).expiring_soon.deliver_later
        end
      end

    end

  end

end
