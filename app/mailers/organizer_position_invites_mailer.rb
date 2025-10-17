# frozen_string_literal: true

class OrganizerPositionInvitesMailer < ApplicationMailer
  before_action :set_invite

  def notify
    # if somebody gets invited with a link, removed, and then invited regularly they wont get an email here
    # we dont currently assosciate OPI and OPIR / OPIL
    unless @invite.event.organizer_position_invite_requests.approved.where(requester: current_user).any?
      mail to: @invite.user.email_address_with_name, subject: @invite.initial? && @invite.event.demo_mode? ? "Thanks for applying for HCB 🚀" : "You've been invited to join #{@invite.event.name} on HCB 🚀"
    end
  end

  def accepted
    unless @invite.event.organizer_position_invite_requests.approved.where(requester: current_user).any?
      @emails = (@invite.event.users.excluding(@invite.user).map(&:email_address_with_name) + [@invite.event.config.contact_email]).compact

      @announcement = Announcement::Templates::NewTeamMember.new(
        invite: @invite,
        author: User.system_user
      ).create
      
      mail to: @emails, subject: "#{@invite.user.name} has accepted their invitation to join #{@invite.event.name}"
    end
  end

  private

  def set_invite
    @invite = params[:invite]
  end

end
