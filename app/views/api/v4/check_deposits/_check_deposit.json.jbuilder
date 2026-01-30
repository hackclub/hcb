# frozen_string_literal: true

json.id check_deposit.public_id
json.status check_deposit.state_text.parameterize(separator: "_")
json.amount_cents check_deposit.amount_cents
json.created_at check_deposit.created_at
json.updated_at check_deposit.updated_at

if check_deposit.rejected? && check_deposit.rejection_reason.present?
  json.rejection do
    json.reason check_deposit.rejection_reason
    json.description check_deposit.rejection_description
  end
end

if check_deposit.estimated_arrival_date.present?
  json.estimated_arrival_date check_deposit.estimated_arrival_date
else
  json.estimated_arrival_date json.nil!
end

if policy(check_deposit).view_image?
  json.front_url Rails.application.routes.url_helpers.rails_blob_url(check_deposit.front) if check_deposit.front.attached?
  json.back_url Rails.application.routes.url_helpers.rails_blob_url(check_deposit.back) if check_deposit.back.attached?
end

json.submitter do
  if check_deposit.created_by.present?
    json.partial! "api/v4/users/user", user: check_deposit.created_by
  else
    json.nil!
  end
end
