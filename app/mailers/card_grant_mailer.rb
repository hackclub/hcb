# frozen_string_literal: true

class CardGrantMailer < ApplicationMailer
  def card_grant_notification
    @card_grant = params[:card_grant]
    @custom_invite_message = @card_grant.invite_message
    purpose_text = " for #{@card_grant.purpose}"

    mail to: @card_grant.user.email_address_with_name, subject: "[#{@card_grant.event.name}] You've received a #{@card_grant.amount.format} grant#{purpose_text if @card_grant.purpose.present?}!"
  end

  def acceptance_reminder
    @card_grant = params[:card_grant]
    return unless @card_grant.pending_invite?
    return if @card_grant.expiration_at < Date.current || @card_grant.suspected_fraud?

    mail to: @card_grant.user.email_address_with_name, subject: "[#{@card_grant.event.name}] Reminder to accept your #{@card_grant.amount.format} grant"
  end

  def card_grant_expiry_notification
    @card_grant = params[:card_grant]
    @expiry_time = params[:expiry_time]

    mail to: @card_grant.user.email_address_with_name, subject: "[#{@card_grant.event.name}] Your #{@card_grant.amount.format} grant expires in #{@expiry_time}"
  end

end
