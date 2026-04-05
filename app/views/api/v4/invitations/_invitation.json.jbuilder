# frozen_string_literal: true

json_object(json, invitation)
json.accepted invitation.accepted?
json.sender { json.partial! "api/v4/users/user", user: invitation.sender }
json.organization { json.partial! "api/v4/events/event", event: invitation.event }
json.role invitation.role
