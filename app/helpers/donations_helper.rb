# frozen_string_literal: true

module DonationsHelper
  def donation_payment_processor_fee(donation = @donation, humanized: true)
    fee = donation.payout_creation_balance_stripe_fee

    return fee unless humanized

    render_money fee
  end

  # this information is visible to admins only because payouts should feel instant to the user
  def donation_payout_datetime(donation = @donation)
    date = nil
    title = nil
    if donation.deposited?
      title = "Funds available since "
      date = donation.canonical_transactions.pluck(:date).max
    elsif donation.payout.nil?
      title = "Transfer scheduled for "
      date = donation.payout_creation_queued_for
    elsif donation.payout.present?
      title = "Funds should be available from "
      date = donation.payout.arrival_date
    end

    return if date.nil? || title.nil?

    strong_tag = content_tag :strong, title
    date_tag = format_date date

    content_tag(:p) { strong_tag + date_tag }
  end

  def donation_payment_method_mention(donation = @donation, **options)
    payment_method_mention(donation, **options)
  end

  def donation_card_country_mention(donation = @donation)
    country_code = donation&.payment_method_card_country

    country_to_emoji(country_code) if country_code
  end

  def donation_fee_type(donation = @donation)
    case donation.payment_method_type
    when "card"
      brand = donation.payment_method_card_brand.humanize.capitalize
      funding = donation.payment_method_card_funding.humanize.capitalize
      return "#{brand} #{funding} card fee"
    when "ach_credit_transfer"
      "ACH / wire fee"
    else
      "Transfer fee"
    end
  end

  def donation_card_check_badge(check, donation = @donation)
    card_check_badge donation.send("payment_method_card_checks_#{check}_check")
  end
end
