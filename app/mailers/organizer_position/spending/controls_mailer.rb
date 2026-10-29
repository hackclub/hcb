# frozen_string_literal: true

class OrganizerPosition
  module Spending
    class ControlsMailer < ApplicationMailer
      def low_balance_warning
        @control = params[:control]
        set_delivery_reason

        mail to: @control.organizer_position.user.email_address_with_name, subject: "Your spending balance on #{@control.organizer_position.event.name} is getting low"
      end

      def new_allowance
        @allowance = params[:allowance]
        @control = @allowance.control
        set_delivery_reason

        mail to: @control.organizer_position.user.email_address_with_name, subject: "Your spending balance on #{@control.organizer_position.event.name} has #{@allowance.amount_cents > 0 ? "increased" : "decreased"}"
      end

      private

      def set_delivery_reason
        @delivery_reason = "you have spending controls on #{@control.organizer_position.event.name} on HCB."
      end

    end
  end

end
