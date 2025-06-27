# frozen_string_literal: true

class OrganizerPosition
  module Spending
    class ControlsMailer < ApplicationMailer
      def low_balance_warning
        @control = params[:control]

        mail to: @control.organizer_position.user.email_address_with_name, subject: "Your spending balance on #{@control.organizer_position.event.name} is getting low"
      end

    end
  end

end
