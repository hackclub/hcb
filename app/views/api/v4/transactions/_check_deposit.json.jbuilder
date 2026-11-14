# frozen_string_literal: true

# locals: (json:, check_deposit:)

json.status check_deposit.state_text.parameterize(separator: "_")

omit_hidden(json) do
  json.front_url Rails.application.routes.url_helpers.rails_blob_url(check_deposit.front)
  json.back_url Rails.application.routes.url_helpers.rails_blob_url(check_deposit.back)
end

json.submitter do
  if check_deposit.created_by.present?
    json.partial! "api/v4/users/user", user: check_deposit.created_by
  else
    json.nil!
  end
end
