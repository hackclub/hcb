# frozen_string_literal: true

# locals: (json:, report:)

object_shape(json, report) do
  json.name report.name
  json.status report.aasm_state
  json.status_text report.status_text
  json.currency report.currency
  json.amount_cents report.amount_cents
  json.maximum_amount_cents report.maximum_amount_cents

  json.submitted_at report.submitted_at
  json.reimbursement_requested_at report.reimbursement_requested_at
  json.reimbursement_approved_at report.reimbursement_approved_at
  json.reimbursed_at report.reimbursed_at
  json.rejected_at report.rejected_at

  expand_association(json, :user, report.user, partial: "api/v4/users/user", as: :user)
  expand_association(json, :organization, report.event, partial: "api/v4/events/event", as: :event)
  expand_association(json, :reviewer, report.reviewer, partial: "api/v4/users/user", as: :user)
end
