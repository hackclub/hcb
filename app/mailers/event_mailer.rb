# frozen_string_literal: true

class EventMailer < ApplicationMailer
  before_action { @event = params[:event] }
  before_action :set_emails

  def monthly_donation_summary
    @event = params[:event]

    @donations = @event.donations.where(created_at: Time.now.last_month.beginning_of_month..).order(:created_at)

    return if @donations.none?

    @total = @donations.sum(:amount)

    mail to: @emails, subject: "#{@event.name} received #{@donations.length} donations this past month"
  end

  private

  def set_emails
    @emails = @event.users.map(&:email_address_with_name)
    @emails << @event.config.contact_email if @event.config.contact_email.present?
  end

end
