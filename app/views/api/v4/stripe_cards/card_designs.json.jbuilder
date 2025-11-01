# frozen_string_literal: true

json.array! @designs do |design|
  json.id design.id
  json.name design.name_without_id
  json.color design.color
  json.status design.stripe_status
  json.common design.common
  json.logo_url rails_blob_url(design.logo) if design.logo.attached?
end
