# frozen_string_literal: true

json.id donation.public_id
json.recurring donation.recurring?
json.donor do
  json.name donation.name
  json.email donation.email
  json.recurring_donor_id donation.recurring_donation.hashid if donation.recurring?
end
json.attribution do
  json.referrer donation.referrer
  json.utm_source donation.utm_source
  json.utm_medium donation.utm_medium
  json.utm_campaign donation.utm_campaign
  json.utm_term donation.utm_term
  json.utm_content donation.utm_content
end
json.payment_method do
  json.type donation.payment_method_type
  json.brand donation.payment_method_card_brand
  json.last4 donation.payment_method_card_last4
  json.funding donation.payment_method_card_funding
  json.exp_month donation.payment_method_card_exp_month
  json.exp_year donation.payment_method_card_exp_year
  json.country donation.payment_method_card_country
end
json.message donation.message
json.donated_at donation.donated_at
json.refunded donation.refunded?
json.deposited donation.deposited?
json.in_transit donation.in_transit?
