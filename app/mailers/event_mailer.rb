# frozen_string_literal: true

class EventMailer < ApplicationMailer
  before_action { @event = params[:event] }
  before_action :set_emails

  def monthly_donation_summary
    @event = params[:event]

    @donations = @event.donations.where(created_at: Time.now.last_month.beginning_of_month..).order(:created_at)
    @total = @donations.sum(:amount)

    mail to: @emails, subject: "Monthly donation summary for #{@event.name}"
  end

  private

  def set_emails
    @emails = @event.users.map(&:email_address_with_name)
    @emails << @event.config.contact_email if @event.config.contact_email.present?
  end

end
