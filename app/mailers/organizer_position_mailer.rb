# frozen_string_literal: true

class OrganizerPositionMailer < ApplicationMailer
  def role_change
    @position = params[:organizer_position]
    @previous_role = params[:previous_role]
    @changer = params[:changer]

    mail to: @position.user.email_address_with_name, subject: "Your role in #{@position.event.name} has been updated"
  end

end
