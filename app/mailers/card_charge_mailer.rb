# frozen_string_literal: true

class CardChargeMailer < ApplicationMailer
  # Reversals of smaller charges, such as the $0 authorizations merchants use
  # to verify a card, aren't worth an email.
  MINIMUM_AMOUNT_CENTS = 1_00

  def reversed
    @ledger_item = params[:ledger_item]
    @card_charge = @ledger_item.linked_object
    @user = @ledger_item.author

    return unless @user.email_charge_notifications_enabled?
    return if @card_charge.amount_cents < MINIMUM_AMOUNT_CENTS

    @merchant_name = @card_charge.merchant_data&.dig("name") || "the merchant"
    @failed_verification_checks = @card_charge.failed_verification_checks
    @delivery_reason = "you have charge notifications enabled for your HCB Visa® Commercial card. #{stripe_issuing_disclosure}"
    @unsubscribe_link = settings_notifications_url

    mail to: @user.email_address_with_name, subject: "Your charge at #{@merchant_name} was reversed"
  end

end
