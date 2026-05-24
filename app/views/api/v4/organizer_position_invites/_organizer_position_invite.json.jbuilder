# frozen_string_literal: true

# locals: (json:, invitation:)

object_shape(json, invitation) do
  can_see_email = policy(invitation).index?

  json.accepted invitation.accepted?
  json.sender { json.partial! "api/v4/users/user", user: invitation.sender, show_email: can_see_email }
  json.invitee { json.partial! "api/v4/users/user", user: invitation.user, show_email: can_see_email || invitation.user == current_user }
  json.organization { json.partial! "api/v4/events/event", event: invitation.event }
  json.role invitation.role
end
