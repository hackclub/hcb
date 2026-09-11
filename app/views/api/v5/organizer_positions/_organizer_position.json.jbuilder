# frozen_string_literal: true

# locals: (json:, organizer_position:)

object_shape(json, organizer_position) do |f|
  f.role organizer_position.role
  f.signee organizer_position.is_signee

  expand_association(f, json, :user, organizer_position.user, partial: "api/v5/users/user", as: :user)
end
