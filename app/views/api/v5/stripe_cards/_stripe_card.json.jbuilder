# frozen_string_literal: true

# locals: (json:, stripe_card:)

object_shape(json, stripe_card) do |f|
  f.type stripe_card.card_type
  f.status stripe_card.status_text.parameterize(separator: "_")
  f.name stripe_card.name

  if stripe_card.initially_activated?
    f.last4 stripe_card.last4
    f.exp_month stripe_card.stripe_exp_month
    f.exp_year stripe_card.stripe_exp_year
  else
    f.last4 nil
  end

  f.total_spent_cents { stripe_card.total_spent } if expand?(:total_spent_cents)
  f.balance_available { stripe_card.balance_available } if expand?(:balance_available)

  expand_association(f, json, :organization,   stripe_card.event,          partial: "api/v5/events/event", as: :event)
  expand_association(f, json, :user,           stripe_card.user,           partial: "api/v5/users/user",   as: :user)
  expand_association(f, json, :last_frozen_by, stripe_card.last_frozen_by, partial: "api/v5/users/user",   as: :user)

  if stripe_card.physical?
    f.nest(:personalization) do
      json.color stripe_card.personalization_design.color
      json.logo_url rails_blob_url(stripe_card.personalization_design.logo)
    end

    f.nest(:shipping) do
      json.status stripe_card.remote_shipping_status
      json.eta stripe_card.shipping_eta
      json.address do
        json.line1 stripe_card.stripe_shipping_address_line1
        json.line2 stripe_card.stripe_shipping_address_line2
        json.city stripe_card.stripe_shipping_address_city
        json.state stripe_card.stripe_shipping_address_state
        json.country stripe_card.stripe_shipping_address_country
        json.postal_code stripe_card.stripe_shipping_address_postal_code
      end
    end
  end
end
