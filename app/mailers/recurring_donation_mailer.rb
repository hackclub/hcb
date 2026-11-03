# frozen_string_literal: true

class RecurringDonationMailer < ApplicationMailer
  before_action { @recurring_donation = params[:recurring_donation] }
  before_action { @delivery_reason = "you set up a recurring donation to #{@recurring_donation.event.name}." }

  def amount_changed
    @previous_amount = params[:previous_amount]

    mail to: @recurring_donation.email, subject: "[#{@recurring_donation.event.name}] Donation amount updated"
  end

  def payment_method_changed
    mail to: @recurring_donation.email, subject: "[#{@recurring_donation.event.name}] Payment details updated"
  end

  def payment_failed
    mail to: @recurring_donation.email, subject: "[#{@recurring_donation.event.name}] Donation payment failed"
  end

  def canceled
    mail to: @recurring_donation.email, subject: "[#{@recurring_donation.event.name}] Donation canceled"
  end

end
