# frozen_string_literal: true

# locals: (json:, donation:)

object_shape(json, donation) do |f|
  f.amount_cents donation.amount
  f.recurring donation.recurring?
  f.status donation.visible_state
  f.date donation.donated_at
  f.refunded donation.refunded?
  f.deposited donation.visible_state == "deposited"
  f.in_transit donation.visible_state == "in_transit"
  f.message donation.message
  f.donated_at donation.donated_at

  # `Donation#name` masks to "Anonymous"; the email does not, which is why it
  # sits in `donor_email` and never reaches the transparency tier.
  f.nest(:donor) do
    json.name donation.name
    json.anonymous donation.anonymous?
    json.avatar donation.avatar
  end
  f.donor_email donation.email
  f.recurring_donor_id { donation.recurring_donation&.hashid }

  f.nest(:attribution) do
    json.referrer donation.referrer
    json.utm_source donation.utm_source
    json.utm_medium donation.utm_medium
    json.utm_campaign donation.utm_campaign
    json.utm_term donation.utm_term
    json.utm_content donation.utm_content
  end

  # `Donation#payment_method` resolves through `stripe_obj`, which retrieves the
  # PaymentIntent from Stripe — an external call per rendered donation. v4 emits
  # these unconditionally, so listing donations there is one Stripe round trip
  # per row. Behind `expand` they cost nothing unless asked for, and the
  # FieldSet block means a viewer who cannot see them never triggers the call
  # at all.
  f.nest(:payment_method) do
    json.type donation.payment_method_type
    json.brand donation.payment_method_card_brand
    json.last4 donation.payment_method_card_last4
    json.funding donation.payment_method_card_funding
    json.exp_month donation.payment_method_card_exp_month
    json.exp_year donation.payment_method_card_exp_year
    json.country donation.payment_method_card_country
  end if expand?(:payment_method)
end
