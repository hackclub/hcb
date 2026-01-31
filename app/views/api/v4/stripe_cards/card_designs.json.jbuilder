# frozen_string_literal: true

json.array! @designs do |design|
  json.id design.id
  json.name design.name_without_id
  json.color design.color
  json.status design.stripe_status
  json.unlisted design.unlisted?
  json.common design.common
  json.logo_url design.logo.attached? ? rails_blob_url(design.logo) : nil
end
