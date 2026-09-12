# frozen_string_literal: true

class CardChargeMailer < ApplicationMailer
  def reversed
    @ledger_item = params[:ledger_item]
    @card_charge = @ledger_item.linked_object
    @user = @card_charge.stripe_cardholder&.user

    return if @user.nil?
    return unless @user.email_charge_notifications_enabled?
    
    @merchant_name = @card_charge.merchant_data&.dig("name") || "the merchant"
    @failed_verification_checks = verification_data.select { |k, v| k.end_with?("check") && v == "mismatch" }.keys

    mail to: @user.email_address_with_name, subject: "Your charge at #{@merchant_name} was reversed"
  end

  private

  def verification_data
    (@card_charge.raw_stripe_transactions.last || @card_charge.raw_pending_stripe_transaction)&.stripe_transaction&.dig("verification_data") || {}
  end
  
end