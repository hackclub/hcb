# frozen_string_literal: true

# locals: (json:, invitation:)

object_shape(json, invitation) do |f|
  f.accepted invitation.accepted?
  f.role invitation.role

  expand_association(f, json, :sender,       invitation.sender, partial: "api/v5/users/user",   as: :user)
  expand_association(f, json, :invitee,      invitation.user,   partial: "api/v5/users/user",   as: :user)
  expand_association(f, json, :organization, invitation.event,  partial: "api/v5/events/event", as: :event)
end
