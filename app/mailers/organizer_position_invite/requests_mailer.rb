# frozen_string_literal: true

class OrganizerPositionInvite
  class RequestsMailer < ApplicationMailer
    before_action :set_request

    def created
      @emails = @request.link.event.organizer_contact_emails(only_managers: true)

      mail to: @emails, subject: "#{@request.requester.name} has requested to join #{@request.link.event.name}"
    end

    def denied
      @email = @request.requester.email_address_with_name

      mail to: @email, subject: "Your request to join #{@request.link.event.name} has been denied"
    end

    private

    def set_request
      @request = params[:request]
    end

  end

end
