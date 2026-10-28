# frozen_string_literal: true

class OrganizerPositionInvitesMailer < ApplicationMailer
  include IndividualDelivery

  before_action :set_invite

  def notify
    if @invite.organizer_position_invite_request.present?
      mail to: @invite.user.email_address_with_name, subject: "Your request to join #{@invite.event.name} has been approved"
    elsif @invite.initial? && @invite.event.demo_mode?
      mail to: @invite.user.email_address_with_name, subject: "Thanks for applying for HCB 🚀"
    else
      mail to: @invite.user.email_address_with_name, subject: "You've been invited to join #{@invite.event.name} on HCB 🚀"
    end
  end

  def accepted
    @emails = (@invite.event.users.excluding(@invite.user).map(&:email_address_with_name) + [@invite.event.config.contact_email]).compact

    @announcement = params[:announcement]

    if @invite.organizer_position_invite_request.present?
      mail_individually @emails, subject: "#{@invite.user.possessive_name} request to join #{@invite.event.name} has been approved"
    else
      mail_individually @emails, subject: "#{@invite.user.name} has accepted their invitation to join #{@invite.event.name}"
    end
  end

  private

  def set_invite
    @invite = params[:invite]
  end

end
