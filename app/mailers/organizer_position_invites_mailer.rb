# frozen_string_literal: true

class OrganizerPositionInvitesMailer < ApplicationMailer
  before_action :set_invite

  def notify
    mail to: @invite.user.email_address_with_name, subject: @invite.initial? && @invite.event.demo_mode? ? "Thanks for applying for HCB 🚀" : "You've been invited to join #{@invite.event.name} on HCB 🚀"
  end

  def accepted
    @emails = (@invite.event.users.except(@invite.user).map(&:email_address_with_name) + [@invite.event.config.contact_email]).compact

    @announcement = Announcement::Templates::NewTeamMember.new(
      invite: @invite,
      author: User.system_user
    ).create

    mail to: @emails, subject: "#{@invite.user.name} has accepted their invitation to join #{@invite.event.name}"
  end

  private

  def set_invite
    @invite = params[:invite]
  end

end
