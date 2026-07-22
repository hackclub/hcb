# frozen_string_literal: true

module Payroll
  class PositionMailerPreview < ActionMailer::Preview
    def onboarded
      position = Payroll::Position.last

      Payroll::PositionMailer.with(position:).onboarded
    end

  end
end