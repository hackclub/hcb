# frozen_string_literal: true

json.created_at event.created_at
json.id event.public_id
json.name event.name
json.country event.country
json.slug event.slug
json.icon event.logo.attached? ? Rails.application.routes.url_helpers.url_for(event.logo) : nil
json.playground_mode event.demo_mode?
json.playground_mode_meeting_requested event.demo_mode_request_meeting_at.present?
json.transparent event.is_public?
json.fee_percentage event.revenue_fee.to_f
json.background_image event.background_image.attached? ? Rails.application.routes.url_helpers.url_for(event.background_image) : nil

if expand?(:balance_cents)
  json.balance_cents event.balance_available
  json.fee_balance_cents event.fronted_fee_balance_v2_cents
end

if expand?(:reporting)
  json.total_spent_cents event.total_spent_cents
  json.total_raised_cents event.total_raised
end

if policy(event).account_number? && expand?(:account_number)
  json.account_number event.account_number
  json.routing_number event.routing_number
  json.swift_bic_code event.bic_code
end

if expand?(:users)
  json.users event.organizer_positions.includes(:user).order(created_at: :desc) do |op|
    json.partial! "api/v4/users/user", user: op.user
    json.joined_at op.created_at
    json.role op.role if Flipper.enabled?(:user_permissions_2024_03_09, event)
  end
end
