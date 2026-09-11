# frozen_string_literal: true

# locals: (json:, check_deposit:)

object_shape(json, check_deposit) do |f|
  f.amount_cents check_deposit.amount
  f.status check_deposit.state_text.parameterize(separator: "_")
  f.front_url { Rails.application.routes.url_helpers.rails_blob_url(check_deposit.front) }
  f.back_url { Rails.application.routes.url_helpers.rails_blob_url(check_deposit.back) }
end
