# frozen_string_literal: true

json.id user.public_id
json.name user.name
json.email user.email
json.avatar profile_picture_for(user, params[:avatar_size].presence&.to_i || 24)
json.shipping_address do
  json.address_line1 user&.stripe_cards&.physical&.last&.stripe_shipping_address_line1
  json.address_line2 user&.stripe_cards&.physical&.last&.stripe_shipping_address_line2
  json.city user&.stripe_cards&.physical&.last&.stripe_shipping_address_city
  json.state user&.stripe_cards&.physical&.last&.stripe_shipping_address_state
  json.country user&.stripe_cards&.physical&.last&.stripe_shipping_address_country
  json.postal_code user&.stripe_cards&.physical&.last&.stripe_shipping_address_postal_code
end
json.admin user.admin?
json.auditor user.auditor?
