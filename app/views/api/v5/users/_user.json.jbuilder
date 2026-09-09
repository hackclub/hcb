# frozen_string_literal: true

# locals: (json:, user:)

object_shape(json, user, created_at: false) do |f|
  # `name` is always present; only the value narrows. See
  # UserPolicy#full_name? for why this is a predicate and not a list entry.
  f.name policy(user).full_name? ? user.name : user.initial_name

  f.avatar profile_picture_for(user, params[:avatar_size].presence&.to_i || 24)
  f.admin user.admin?
  f.auditor user.auditor?
  f.email user.email
  f.birthday user.birthday
end
