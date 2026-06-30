# frozen_string_literal: true

class AnnouncementMailer < ApplicationMailer
  before_action :set_warning_variables, only: [:seven_day_warning, :two_day_warning, :skipped]

  def announcement_published
    @announcement = params[:announcement]
    @event = @announcement.event
    @delivery_reason = "you are following #{@event.name} on HCB."
    @unsubscribe_link = event_url(@event)

    mail to: params[:email], subject: "#{@announcement.title} | #{@event.name}", from: hcb_email_with_name_of(@event)
  end

  def seven_day_warning
    mail to: @emails, subject: "[#{@event.name}] Your scheduled monthly announcement will be delivered on #{@scheduled_for.strftime("%B #{@scheduled_for.day.ordinalize}")}"
  end

  def two_day_warning
    mail to: @emails, subject: "[#{@event.name}] Your scheduled monthly announcement will be delivered on #{@scheduled_for.strftime("%B #{@scheduled_for.day.ordinalize}")}"
  end

  def skipped
    mail to: @emails, subject: "[#{@event.name}] Your scheduled monthly announcement has been skipped"
  end

  def notice
    @event = params[:event]
    @emails = @event.organizer_contact_emails(only_managers: true)
    @delivery_reason = "you are on the team of #{@event.name} on HCB."

    @monthly_announcement = params[:monthly_announcement]
    @scheduled_for = Date.today.next_month.beginning_of_month
    @warning_date = @scheduled_for - 7.days

    mail to: @emails, subject: "[#{@event.name}] Monthly announcements have been enabled for your organization"
  end

  private

  def set_warning_variables
    @announcement = params[:announcement]
    @event = @announcement.event
    @delivery_reason = "you are subscribed to monthly announcements for #{@event.name} on HCB."
    @unsubscribe_link = event_url(@event)

    @emails = @event.organizer_contact_emails(only_managers: true)

    @scheduled_for = Date.today.next_month.beginning_of_month
  end

end
