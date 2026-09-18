# frozen_string_literal: true

pagination_metadata(json)

json.data @reports, partial: "api/v4/reimbursement/reports/report", as: :report
