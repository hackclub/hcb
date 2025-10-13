# frozen_string_literal: true

class OrganizerPosition
  module Spending
    class ControlsMailerPreview < ActionMailer::Preview
      def low_balance_warning
        ControlsMailer.with(control: Control.last).low_balance_warning
      end

      def new_allowance
        ControlsMailer.with(allowance: Control::Allowance.last).new_allowance
      end

    end
  end

end
