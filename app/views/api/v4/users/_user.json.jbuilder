# frozen_string_literal: true

# locals: (json:, user:, show_email: nil)

# attributes suitable for public consumption:
object_shape(json, user, created_at: false) do
  json.avatar profile_picture_for(user, params[:avatar_size].presence&.to_i || 24)
  json.admin user.admin?
  json.auditor user.auditor?
  json.name user.initial_name

  # those which we'd like to expose less of:
  expand_pii(override_if: user == current_user || local_assigns[:show_email]) do
    json.email user.email
  end

  expand_pii(override_if: user == current_user) do
    json.birthday user.birthday
    if expand?(:shipping_address)
      json.shipping_address do
        json.address_line1 user&.stripe_cards&.physical&.last&.stripe_shipping_address_line1
        json.address_line2 user&.stripe_cards&.physical&.last&.stripe_shipping_address_line2
        json.city user&.stripe_cards&.physical&.last&.stripe_shipping_address_city
        json.state user&.stripe_cards&.physical&.last&.stripe_shipping_address_state
        json.country user&.stripe_cards&.physical&.last&.stripe_shipping_address_country
        json.postal_code user&.stripe_cards&.physical&.last&.stripe_shipping_address_postal_code
      end
    end
    if expand?(:billing_address)
      json.billing_address do
        json.address_line1 user&.stripe_cardholder&.stripe_billing_address_line1
        json.address_line2 user&.stripe_cardholder&.stripe_billing_address_line2
        json.city user&.stripe_cardholder&.stripe_billing_address_city
        json.state user&.stripe_cardholder&.stripe_billing_address_state
        json.country user&.stripe_cardholder&.stripe_billing_address_country
        json.postal_code user&.stripe_cardholder&.stripe_billing_address_postal_code
      end
    end
  end
end
