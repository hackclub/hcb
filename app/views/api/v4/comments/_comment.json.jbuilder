# frozen_string_literal: true

object_shape(json, comment) do
  json.user comment.user, partial: "api/v4/users/user", as: :user
  json.content comment.content
  json.file rails_blob_url(comment.file) if comment.file.attached?

  if comment.admin_only
    json.admin_only true
  end
end
