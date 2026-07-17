# frozen_string_literal: true

# locals: (json:, recurring_donation:)

object_shape(json, recurring_donation) do
  json.amount_cents recurring_donation.amount
  json.status recurring_donation.stripe_status
  json.donor do
    json.name recurring_donation.name
    json.email recurring_donation.email
  end
  json.message recurring_donation.message
  json.anonymous recurring_donation.anonymous
  json.tax_deductible recurring_donation.tax_deductible
  json.fee_covered recurring_donation.fee_covered
  json.payment_method do
    json.last4 recurring_donation.last4
  end
  json.current_period_end_at recurring_donation.stripe_current_period_end
  json.canceled_at recurring_donation.canceled_at

  expand_association(json, :organization, recurring_donation.event,
                     partial: "api/v4/events/event", as: :event)

  json.total_donated_cents recurring_donation.total_donated if expand?(:total_donated_cents)
end
