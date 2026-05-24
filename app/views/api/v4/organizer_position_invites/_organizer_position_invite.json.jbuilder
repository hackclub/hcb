# frozen_string_literal: true

# locals: (json:, invitation:)

object_shape(json, invitation) do
  can_see_email = policy(invitation).index?

  json.accepted invitation.accepted?
  expand_association(json, :sender,       invitation.sender, partial: "api/v4/users/user",   as: :user,  locals: { show_email: can_see_email })
  expand_association(json, :invitee,      invitation.user,   partial: "api/v4/users/user",   as: :user,  locals: { show_email: can_see_email || invitation.user == current_user })
  expand_association(json, :organization, invitation.event,  partial: "api/v4/events/event", as: :event)
  json.role invitation.role
end
