# frozen_string_literal: true

# locals: (json:, organizer_position:)

object_shape(json, organizer_position) do
  json.role organizer_position.role
  json.signee organizer_position.is_signee
  json.user do
    json.partial! "api/v4/users/user", user: organizer_position.user, show_email: shares_org_with?(organizer_position.user)
  end
end
