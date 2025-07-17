# frozen_string_literal: true

class AnnouncementMailer < ApplicationMailer
  def announcement_published
    @announcement = params[:announcement]
    @event = @announcement.event

    mail to: params[:email], subject: "#{@announcement.title} | #{@event.name}", from: hcb_email_with_name_of(@event)
  end

  def monthly_warning
    @announcement = params[:announcement]

    @emails = @event.managers.map(&:email_address_with_name)
    @emails << @event.config.contact_email if @event.config.contact_email.present?

    @scheduled_for = Date.today.next_month.beginning_of_month
    mail to: @emails, subject: "[#{@announcement.event.name}] Your scheduled monthly announcement will be delivered on #{@scheduled_for.strftime("%b %-m")}"
  end

end
