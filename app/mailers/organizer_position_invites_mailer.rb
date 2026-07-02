# frozen_string_literal: true

class OrganizerPositionInvitesMailer < ApplicationMailer
  before_action :set_invite

  def notify
    if @invite.organizer_position_invite_request.present?
      @delivery_reason = "you requested to join an organization on HCB."
      mail to: @invite.user.email_address_with_name, subject: "Your request to join #{@invite.event.name} has been approved"
    elsif @invite.initial? && @invite.event.demo_mode?
      @delivery_reason = "you applied for fiscal sponsorship with HCB."
      mail to: @invite.user.email_address_with_name, subject: "Thanks for applying for HCB 🚀"
    else
      @delivery_reason = "you have been invited to join an organization on HCB."
      mail to: @invite.user.email_address_with_name, subject: "You've been invited to join #{@invite.event.name} on HCB 🚀"
    end
  end

  def accepted
    @delivery_reason = "you are a member of this organization on HCB."
    @emails = (@invite.event.users.excluding(@invite.user).map(&:email_address_with_name) + [@invite.event.config.contact_email]).compact

    @announcement = Announcement::Templates::NewTeamMember.new(
      invite: @invite,
      author: User.system_user
    ).create

    if @invite.organizer_position_invite_request.present?
      mail to: @emails, subject: "#{@invite.user.possessive_name} request to join #{@invite.event.name} has been approved"
    else
      mail to: @emails, subject: "#{@invite.user.name} has accepted their invitation to join #{@invite.event.name}"
    end
  end

  private

  def set_invite
    @invite = params[:invite]
  end

end
