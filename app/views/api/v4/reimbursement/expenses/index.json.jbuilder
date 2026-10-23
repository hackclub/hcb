# frozen_string_literal: true

pagination_metadata(json)

json.data @expenses, partial: "api/v4/reimbursement/expenses/expense", as: :expense
