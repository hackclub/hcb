# frozen_string_literal: true

module InvoicesHelper
  def invoice_sent_at(invoice = @invoice)
    format_datetime invoice.created_at
  end

  def invoice_payment_processor_fee(invoice = @invoice, humanized: true)
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

  def invoice_payment_method_mention(invoice = @invoice, **options)
    payment_method_mention(invoice, **options, manually_marked_as_paid: invoice&.manually_marked_as_paid?)
  end

  def invoice_card_country_mention(invoice = @invoice)
    country_code = invoice&.payment_method_card_country

    country_to_emoji(country_code) if country_code
  end

  def invoice_card_check_badge(check, invoice = @invoice)
    card_check_badge invoice.send("payment_method_card_checks_#{check}_check")
  end

  # this information is visible to admins only because payouts should feel instant to the user
  def invoice_payout_datetime(invoice = @invoice)
    date = nil
    title = nil
    if invoice.paid_v2? && invoice.deposited? && invoice.payout.present?
      title = "Funds available since "
      date = invoice.canonical_transactions.pluck(:date).max
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
    case invoice.payment_method_type
    when "card"
      brand = invoice.payment_method_card_brand.humanize.capitalize
      funding = invoice.payment_method_card_funding.humanize.downcase
      return "#{brand} #{funding} card fee"
    when "ach_credit_transfer"
      "ACH / wire fee"
    else
      "Transfer fee"
    end
  end
end
