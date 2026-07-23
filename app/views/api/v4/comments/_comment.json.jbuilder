# frozen_string_literal: true

# locals: (json:, comment:)

object_shape(json, comment) do
  json.user comment.user, partial: "api/v4/users/user", as: :user
  json.content comment.content
  if comment.attached_files.any?
    json.files comment.attached_files.map { |file| rails_blob_url(file) }
  end

  if comment.admin_only
    json.admin_only true
  end
end
