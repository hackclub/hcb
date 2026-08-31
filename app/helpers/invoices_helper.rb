# frozen_string_literal: true

module InvoicesHelper
  def invoice_sent_at(invoice = @invoice)
    format_datetime invoice.created_at
  end

  def invoice_payment_method(invoice = @invoice)
    if invoice.manually_marked_as_paid?
      return "–"
    elsif invoice&.payout
      return invoice.payout.source_type.humanize
    end
  end

  def invoice_payment_processor_fee(humanized = true, invoice = @invoice)
    fee = if invoice.manually_marked_as_paid?
            0
          elsif invoice&.paid_at&.< Date.new(2024, 8, 21)
            invoice.item_amount - invoice.payout.amount
          else
            invoice.payout_creation_balance_stripe_fee
          end
    # for many years, we were calculating the fee to reimburse for invoices wrongly.
    # https://github.com/hackclub/hcb/issues/7636 - @sampoder

    return fee unless humanized

    render_money fee
  end
end

def invoice_payment_method_mention(invoice = @invoice, **options)
  return "–" unless invoice&.manually_marked_as_paid? || invoice&.payment_method_type

  if invoice.manually_marked_as_paid?
    size = 20
    icon_name = "post-fill"
    description_text = "Manually marked as paid"
  elsif invoice&.payment_method_card_brand
    brand = invoice&.payment_method_card_brand
    last4 = invoice&.payment_method_card_last4

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

    if invoice&.payment_method_type == "ach_credit_transfer"
      description_text = "ACH transfer"
    elsif invoice&.payment_method_type == "us_bank_account"
      description_text = "US bank account"
    else
      description_text = invoice.payment_method_type.humanize
    end
  end

  description = content_tag :span, description_text, class: "ml1"
  icon ||= inline_icon icon_name, width: size, height: size, class: "slate"
  content_tag(:span, class: "inline-flex items-center #{options[:class]}") { icon + description }
end

def invoice_card_country_mention(invoice = @invoice)
  country_code = invoice&.payment_method_card_country

  return nil unless country_code

  # Hack to turn country code into the country's flag
  # https://stackoverflow.com/a/50859942
  emoji = country_code.tr("A-Z", "\u{1F1E6}-\u{1F1FF}")

  content_tag :span, emoji, class: "tooltipped tooltipped--w pr1", 'aria-label': country_code
end

def invoice_card_check_badge(check, invoice = @invoice)
  case invoice.send("payment_method_card_checks_#{check}_check")
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

# this information is visible to admins only because payouts should feel instant to the user
def invoice_payout_datetime(invoice = @invoice)
  date = nil
  title = nil
  if invoice.paid_v2? && invoice.deposited? && invoice.payout.present?
    title = "Funds available since "
    date = @hcb_code.canonical_transactions.pluck(:date).max
  elsif invoice.payout_creation_queued_at && invoice.payout.nil?
    title = "Transfer scheduled "
    date = invoice.payout_creation_queued_for
  elsif invoice.payout_creation_queued_at && invoice.payout.present?
    title = "Funds should be available "
    date = invoice.arrival_date
  end

  return if date.nil? || title.nil?

  strong_tag = content_tag :strong, title
  date_tag = format_date date

  content_tag(:p) { strong_tag + date_tag }
end

def invoice_fee_type(invoice = @invoice)
  case @invoice.payment_method_type
  when "card"
    brand = @invoice.payment_method_card_brand.humanize.capitalize
    funding = @invoice.payment_method_card_funding.humanize.downcase
    return "#{brand} #{funding} card fee"
  when "ach_credit_transfer"
    "ACH / wire fee"
  else
    "Transfer fee"
  end
end
