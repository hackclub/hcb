# frozen_string_literal: true

module PaymentMethodsHelper
  CARD_BRAND_ICONS = {
    "amex"       => "card-amex",
    "mastercard" => "card-mastercard",
    "visa"       => "card-visa",
    "discover"   => "card-discover"
  }.freeze

  # Renders an icon + label describing how a donation or invoice was paid.
  # `record` must respond to payment_method_type, payment_method_card_brand and payment_method_card_last4.
  def payment_method_mention(record, manually_marked_as_paid: false, **options)
    return "–" unless manually_marked_as_paid || record&.payment_method_type

    if manually_marked_as_paid
      size = 20
      icon_name = "post-fill"
      description_text = "Manually marked as paid"
    elsif record.payment_method_card_brand
      icon_name = CARD_BRAND_ICONS[record.payment_method_card_brand] || "card-other"
      description_text = organizer_signed_in? ? "••••#{record.payment_method_card_last4}" : "••••"
      icon = inline_icon icon_name, width: 32, height: 20, class: "slate"
    else
      icon_name = "bank-account"
      size = 20

      description_text =
        case record.payment_method_type
        when "ach_credit_transfer" then "ACH transfer"
        when "us_bank_account" then "US bank account"
        else record.payment_method_type.humanize
        end
    end

    description = content_tag :span, description_text, class: "ml1"
    icon ||= inline_icon icon_name, width: size, height: size, class: "slate"
    content_tag(:span, class: "inline-flex items-center #{options[:class]}") { icon + description }
  end
end
