# frozen_string_literal: true

class Event
  class TerminationRequestMailer < ::ApplicationMailer
    before_action do
      @termination_request = params[:termination_request]
      @event = @termination_request.event
      @requested_by = @termination_request.requested_by
    end

    def notify_operations
      mail to: OPERATIONS_EMAIL,
           subject: "#{@requested_by.name} is requesting the termination of #{@event.name}"
    end

    def confirmation
      mail to: @requested_by.email_address_with_name,
           subject: "We've received your request to terminate #{@event.name}"
    end

  end

end
