# frozen_string_literal: true

module DonationsHelper
  def donation_payment_processor_fee(humanized = true, donation = @donation)
    fee = donation.payout_creation_balance_stripe_fee

    return fee unless humanized

    render_money fee
  end

  def donation_payout_type(humanized = true, donation = @donation)
    return humanized ? "–" : nil unless donation.payout

    donation.payout&.type
  end

  def donation_paid_at(donation = @donation)
    timestamp = donation&.payout&.created_at
    timestamp ? format_datetime(timestamp) : "–"
  end

  # this information is visible to admins only because payouts should feel instant to the user
  def donation_payout_datetime(donation = @donation)
    date = nil
    title = nil
    if donation.deposited?
      title = "Funds available since "
      date = @hcb_code.canonical_transactions.pluck(:date).max
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
    payout = donation&.payout
    payout_t = donation&.payout&.t_transaction

    return "–" unless donation&.payment_method_type

    if donation&.payment_method_card_brand
      brand = donation&.payment_method_card_brand
      last4 = donation&.payment_method_card_last4

      icon_name = {
        "amex"       => "card-amex",
        "mastercard" => "card-mastercard",
        "visa"       => "card-visa",
        "discover"   => "card-discover"
      }[brand] || "card-other"
      tooltip = {
        "amex"       => "American Express",
        "mastercard" => "Mastercard",
        "visa"       => "Visa",
        "discover"   => "Discover"
      }[brand] || "Card"
      tooltip += " ending in #{last4}" if last4 && organizer_signed_in?
      description_text = organizer_signed_in? ? "••••#{last4}" : "••••"
      icon = inline_icon icon_name, width: 32, height: 20, class: "slate"
    else
      icon_name = "bank-account"
      size = 20

      if donation&.payment_method_type == "ach_credit_transfer"
        description_text = "ACH Transfer"
      else
        description_text = donation.payment_method_type.humanize
      end
    end

    description = content_tag :span, description_text, class: "ml1"
    icon ||= inline_icon icon_name, width: size, height: size, class: "slate"
    content_tag(:span, class: "inline-flex items-center #{options[:class]}") { icon + description }
  end

  def donation_card_country_mention(donation = @donation)
    country_code = donation&.payment_method_card_country

    return nil unless country_code

    # Hack to turn country code into the country's flag
    # https://stackoverflow.com/a/50859942
    emoji = country_code.tr("A-Z", "\u{1F1E6}-\u{1F1FF}")

    content_tag :span, emoji, class: "tooltipped tooltipped--w pr1", 'aria-label': country_code
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
    case donation.send("payment_method_card_checks_#{check}_check")
    when "pass"
      background = "success"
      icon_name = "checkmark"
      text = "Passed"
    when "failed"
      background = "warning"
      icon_name = "view-close"
      text = "Failed"
    when "unchecked"
      background = "info"
      icon_name = "checkbox"
      text = "Unchecked"
    else
      background = "smoke"
      icon_name = "checkbox"
      text = "Unavailable"
    end

    tag = inline_icon icon_name, size: 24
    content_tag(:span, class: "pr1 #{background} line-height-0 tooltipped tooltipped--w", 'aria-label': text) { tag }
  end
end
