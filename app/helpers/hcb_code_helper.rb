# frozen_string_literal: true

module HcbCodeHelper
  def attach_receipt_url(hcb_code)
    Rails.application.routes.url_helpers.attach_receipt_hcb_code_url(
      id: hcb_code.hashid,
      s: hcb_code.signed_id(expires_in: 2.weeks, purpose: :receipt_upload)
    )
  end

  def can_dispute?(hcb_code:)
    can_dispute, error_reason = ::HcbCodeService::CanDispute.new(hcb_code:).run

    can_dispute
  end

  def country_to_emoji(country_code)
    # Hack to turn country code into the country's flag
    # https://stackoverflow.com/a/50859942
    emoji = country_code.tr("A-Z", "\u{1F1E6}-\u{1F1FF}")

    content_tag :span, emoji, class: "tooltipped tooltipped--w pr1", 'aria-label': country_code
  end

  def stripe_verification_check_badge(check, verification_data = @verification_data)
    card_check_badge verification_data["#{check}_check"]
  end

  # Renders a badge for the result of a card verification check (CVC, postal
  # code, etc.). Accepts both Stripe Payments statuses (pass / failed /
  # unchecked) and Stripe Issuing statuses (match / mismatch / not_provided).
  CARD_CHECK_BADGES = {
    "pass"         => { background: "success", icon_name: "checkmark", text: "Passed" },
    "match"        => { background: "success", icon_name: "checkmark", text: "Passed" },
    "failed"       => { background: "warning", icon_name: "view-close", text: "Failed" },
    "mismatch"     => { background: "warning", icon_name: "view-close", text: "Failed" },
    "unchecked"    => { background: "info", icon_name: "checkbox", text: "Unchecked" },
    "not_provided" => { background: "info", icon_name: "checkbox", text: "Not checked" },
  }.freeze
  CARD_CHECK_BADGE_UNAVAILABLE = { background: "smoke", icon_name: "checkbox", text: "Unavailable" }.freeze

  def card_check_badge(status)
    badge = CARD_CHECK_BADGES.fetch(status, CARD_CHECK_BADGE_UNAVAILABLE)

    tag = inline_icon badge[:icon_name], size: 24
    content_tag(:span, class: "pr1 #{badge[:background]} line-height-0 tooltipped tooltipped--w", 'aria-label': badge[:text]) { tag }
  end
end
