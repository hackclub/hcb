# frozen_string_literal: true

# locals: (json:, expense:)

object_shape(json, expense) do
  json.memo expense.memo
  json.description expense.description
  json.category expense.category
  json.expense_type expense.expense_type_name
  json.amount_cents expense.amount_cents
  json.value expense.value.to_f
  json.status expense.aasm_state
  json.approved_at expense.approved_at

  expand_association(json, :report, expense.report, partial: "api/v4/reimbursement/reports/report", as: :report)
end
