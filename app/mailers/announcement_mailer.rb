# frozen_string_literal: true

class AnnouncementMailer < ApplicationMailer
  def announcement_published
    @announcement = params[:announcement]
    @event = @announcement.event

    mail to: params[:email], subject: "#{@announcement.title} | #{@event.name}", from: hcb_email_with_name_of(@event)
  end

  def monthly_warning
    @event = params[:event]
    @announcement = Announcement.where(event: @event).monthly.last

    @emails = @event.users.map(&:email_address_with_name)
    @emails << @event.config.contact_email if @event.config.contact_email.present?

    mail to: @emails, subject: "WARNING: A scheduled announcement will go out in one week"
  end

end
