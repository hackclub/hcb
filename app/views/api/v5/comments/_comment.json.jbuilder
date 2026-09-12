# frozen_string_literal: true

# locals: (json:, comment:)

object_shape(json, comment) do |f|
  f.content comment.content
  f.admin_only comment.admin_only
  f.file { comment.file.attached? ? rails_blob_url(comment.file) : nil }

  f.nest(:user) do
    if comment.user.present?
      json.partial! "api/v5/users/user", user: comment.user
    else
      json.nil!
    end
  end
end
