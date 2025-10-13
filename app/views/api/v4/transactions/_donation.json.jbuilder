# frozen_string_literal: true

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
json.message donation.message
json.donated_at donation.donated_at
json.refunded donation.refunded?
