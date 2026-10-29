# frozen_string_literal: true

module Payroll
  class PositionMailerPreview < ActionMailer::Preview
    def onboarded
      position = Payroll::Position.last

      Payroll::PositionMailer.with(position:).onboarded
    end

    def expiring_soon
      position = Payroll::Position.last

      Payroll::PositionMailer.with(position:).expiring_soon
    end

  end
end
