# frozen_string_literal: true

class AnnouncementMailer < ApplicationMailer
  before_action :set_warning_variables, only: [:seven_day_warning, :two_day_warning]

  def announcement_published
    @announcement = params[:announcement]
    @event = @announcement.event

    mail to: params[:email], subject: "#{@announcement.title} | #{@event.name}", from: hcb_email_with_name_of(@event)
  end

  def seven_day_warning
    mail to: @emails, subject: "[#{@event.name}] Your scheduled monthly announcement will be delivered on #{@scheduled_for.strftime("%b %-d")}"
  end

  def two_day_warning
    mail to: @emails, subject: "[#{@event.name}] Your scheduled monthly announcement will be delivered on #{@scheduled_for.strftime("%b %-d")}"
  end

  def notice
    @event = params[:event]
    set_manager_emails

    @monthly_announcement = params[:monthly_announcement]
    if @monthly_announcement.present?
      @scheduled_for = Date.today.next_month.beginning_of_month
    end

    mail to: @emails, subject: "[#{@event.name}] Announcing organization announcements!"
  end

  def set_warning_variables
    @announcement = params[:announcement]
    @event = @announcement.event

    set_manager_emails

    @scheduled_for = Date.today.next_month.beginning_of_month
  end

  def set_manager_emails
    @emails = @event.managers.map(&:email_address_with_name)
    @emails << @event.config.contact_email if @event.config.contact_email.present?
  end

end
