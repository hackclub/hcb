# frozen_string_literal: true

# locals: (json:, event:)

object_shape(json, event, object_name: "organization") do |f|
  f.parent_id event.parent&.public_id
  f.name event.name
  f.slug event.slug
  f.country event.country
  f.website event.website
  f.transparent event.is_public?
  f.playground_mode event.demo_mode?
  f.financially_frozen event.financially_frozen?
  f.donation_page_available event.donation_page_available?
  f.fee_percentage event.revenue_fee.to_f
  f.public_message { event.public_message.presence }
  f.icon { event.logo.attached? ? Rails.application.routes.url_helpers.url_for(event.logo) : nil }
  f.background_image { event.background_image.attached? ? Rails.application.routes.url_helpers.url_for(event.background_image) : nil }
  f.donation_header { event.donation_header_image.attached? ? Rails.application.routes.url_helpers.url_for(event.donation_header_image) : nil }

  if expand?(:plan)
    f.nest(:plan) do
      json.name event.plan.label
      json.fee_percentage event.revenue_fee.to_f
      json.features event.plan.features
    end
  end

  if expand?(:balance_cents)
    f.balance_cents { event.balance_available }
    f.fee_balance_cents { event.fronted_fee_balance_v2_cents }
    f.incoming_balance_cents { event.pending_incoming_balance_v2_cents }
  end

  if expand?(:reporting)
    f.total_spent_cents { event.total_spent_cents }
    f.total_raised_cents { event.total_raised }
  end

  if expand?(:account_number)
    f.account_number { event.account_number }
    f.routing_number { event.routing_number }
    f.swift_bic_code { event.bic_code }
  end

  if expand?(:users)
    f.nest(:users) do
      json.array! event.organizer_positions.includes(user: :organizer_positions).order(created_at: :desc) do |op|
        json.partial! "api/v5/users/user", user: op.user
        json.joined_at op.created_at
        json.role op.role
      end
    end
  end
end
