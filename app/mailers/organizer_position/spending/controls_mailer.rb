# frozen_string_literal: true

class OrganizerPosition
  module Spending
    class ControlsMailer < ApplicationMailer
      def warning
        @control = params[:control]
        @controls_path = Rails.application.routes.url_helpers.event_organizer_position_spending_controls_path(event_id: @control.organizer_position.event, organizer_position_id: @control.organizer_position)

        mail to: @control.organizer_position.user.email_address_with_name, subject: "Your spending balance on #{@control.organizer_position.event.name} is getting low"
      end

    end
  end

end
