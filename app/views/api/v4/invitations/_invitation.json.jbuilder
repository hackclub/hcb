# frozen_string_literal: true

# locals: (json:, invitation:)

object_shape(json, invitation) do
  json.accepted invitation.accepted?
  json.sender { json.partial! "api/v4/users/user", user: invitation.sender }
  json.organization { json.partial! "api/v4/events/event", event: invitation.event }
  json.role invitation.role
end
