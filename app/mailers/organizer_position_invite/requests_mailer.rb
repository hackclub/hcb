# frozen_string_literal: true

class OrganizerPositionInvite
  class RequestsMailer < ApplicationMailer
    before_action :set_request

    def created
      @emails = @request.link.event.organizer_contact_emails(only_managers: true)

      mail to: @emails, subject: "#{@request.requester.name} has requested to join #{@request.link.event.name}"
    end

    def approved
      @invite = @request.organizer_position_invite
      @emails = (@invite.event.users.map(&:email_address_with_name) + [@invite.event.config.contact_email]).compact

      @announcement = Announcement::Templates::NewTeamMember.new(
        invite: @invite,
        author: User.system_user
      ).create

      # should we make a different email for the one whose request was approved?
      mail to: @emails, subject: "#{@invite.user.possessive_name} request to join #{@invite.event.name} has been approved"
    end

    def denied
      @email = @request.requester.email

      mail to: @email, subject: "Your request to join #{@request.link.event.name} has been denied"
    end

    private

    def set_request
      @request = params[:request]
    end

  end
  end

end
