# frozen_string_literal: true

class AnnouncementMailer < ApplicationMailer
  before_action :set_warning_variables, only: [:seven_day_warning, :two_day_warning, :canceled]

  def announcement_published
    @announcement = params[:announcement]
    @event = @announcement.event

    mail to: params[:email], subject: "#{@announcement.title} | #{@event.name}", from: hcb_email_with_name_of(@event)
  end

  def seven_day_warning
    mail to: @emails, subject: "[#{@event.name}] Your scheduled monthly announcement will be delivered on #{@scheduled_for.strftime("%B #{@scheduled_for.day.ordinalize}")}"
  end

  def two_day_warning
    mail to: @emails, subject: "[#{@event.name}] Your scheduled monthly announcement will be delivered on #{@scheduled_for.strftime("%B #{@scheduled_for.day.ordinalize}")}"
  end

  def canceled
    mail to: @emails, subject: "[#{@event.name}] Your scheduled monthly announcement has been canceled"
  end

  def set_warning_variables
    @announcement = params[:announcement]
    @event = @announcement.event

    @emails = @event.managers.map(&:email_address_with_name)
    @emails << @event.config.contact_email if @event.config.contact_email.present?

    @scheduled_for = Date.today.next_month.beginning_of_month
  end

end
