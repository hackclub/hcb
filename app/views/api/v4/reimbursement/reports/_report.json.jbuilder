# frozen_string_literal: true

# locals: (json:, report:)

object_shape(json, report) do
  json.name report.name
  json.status report.aasm_state
  json.currency report.currency
  json.amount_cents report.amount_cents
  json.maximum_amount_cents report.maximum_amount_cents

  json.submitted_at report.submitted_at
  json.reimbursement_requested_at report.reimbursement_requested_at
  json.reimbursement_approved_at report.reimbursement_approved_at
  json.reimbursed_at report.reimbursed_at
  json.rejected_at report.rejected_at

  if expand?(:user)
    json.user report.user, partial: "api/v4/users/user", as: :user
  else
    json.user_id report.user.public_id
  end

  if report.event.present?
    if expand?(:organization)
      json.organization report.event, partial: "api/v4/events/event", as: :event
    else
      json.organization_id report.event.public_id
    end
  else
    json.organization_id nil
  end

  if expand?(:reviewer)
    json.reviewer do
      if report.reviewer.present?
        json.partial! "api/v4/users/user", user: report.reviewer
      else
        json.nil!
      end
    end
  else
    json.reviewer_id report.reviewer&.public_id
  end
end
