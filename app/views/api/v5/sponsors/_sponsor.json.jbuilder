# frozen_string_literal: true

# locals: (json:, sponsor:)

object_shape(json, sponsor) do |f|
  f.name sponsor.name
  f.slug sponsor.slug
  f.event_id sponsor.event&.public_id
  f.contact_email sponsor.contact_email
  f.address_line1 sponsor.address_line1
  f.address_line2 sponsor.address_line2
  f.address_city sponsor.address_city
  f.address_state sponsor.address_state
  f.address_postal_code sponsor.address_postal_code
  f.address_country sponsor.address_country
  f.stripe_customer_id sponsor.stripe_customer_id
end
