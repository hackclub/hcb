# frozen_string_literal: true

class CardChargeMailer < ApplicationMailer
  def reversed
    @ledger_item = params[:ledger_item]
    @card_charge = @ledger_item.linked_object
    amount_cents = @ledger_item.amount_cents.abs
    @user = @ledger_item.author

    return unless @user.email_charge_notifications_enabled?

    @merchant_name = @card_charge.merchant_data&.dig("name") || "the merchant"
    @failed_verification_checks = verification_data.select { |k, v| k.end_with?("check") && v == "mismatch" }.keys

    @insufficient_balance = balance_before_charge_cents < amount_cents
    @spending_limit_exceeded = spending_limit_exceeded?(@card_charge.stripe_card, amount_cents)

    mail to: @user.email_address_with_name, subject: "Your charge at #{@merchant_name} was reversed"
  end

  private

  def verification_data
    (@card_charge.raw_stripe_transactions.last || @card_charge.raw_pending_stripe_transaction)&.stripe_transaction&.dig("verification_data") || {}
  end

  def balance_before_charge_cents
    @card_charge.stripe_card.event.balance_v2_cents(end_date: @ledger_item.datetime) - @ledger_item.amount_cents
  end

  def spending_limit_exceeded?(stripe_card, amount_cents)
    return false if stripe_card.spending_limit_amount.blank?

    case stripe_card.spending_limit_interval
    when "per_authorization"
      amount_cents > stripe_card.spending_limit_amount
    when "all_time"
      spent_since_card_created(stripe_card) > stripe_card.spending_limit_amount
    else # daily, weekly, monthly, yearly
      spent_in_current_interval(stripe_card) > stripe_card.spending_limit_amount
    end
  end

  INTERVAL_TO_UNIT = {
    "daily"   => "day",
    "weekly"  => "week",
    "monthly" => "month",
    "yearly"  => "year",
  }.freeze

  def spent_in_current_interval(stripe_card)
    unit = INTERVAL_TO_UNIT.fetch(stripe_card.spending_limit_interval)
    interval_start = @ledger_item.datetime.public_send("beginning_of_#{unit}")
    spent_cents(stripe_card, since: interval_start)
  end

  def spent_since_card_created(stripe_card)
    spent_cents(stripe_card, since: stripe_card.created_at)
  end

  def spent_cents(stripe_card, since:)
    stripe_card.card_charges
               .joins(:ledger_item)
               .where(ledger_item: { datetime: since..@ledger_item.datetime })
               .where("ledger_item.amount_cents < 0")
               .sum("ledger_item.amount_cents").abs
  end

end
