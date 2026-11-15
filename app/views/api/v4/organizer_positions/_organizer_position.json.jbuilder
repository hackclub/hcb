# frozen_string_literal: true

# locals: (json:, organizer_position:)

object_shape(json, organizer_position) do
  json.role organizer_position.role
  json.signee organizer_position.is_signee
  expand_association(json, :user, organizer_position.user, partial: "api/v4/users/user", as: :user, locals: { show_email: shares_org_with?(organizer_position.user) })
end
