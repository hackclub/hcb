# frozen_string_literal: true

json.organizers @organizer_positions do |op|
  json.id op.public_id
  json.role op.role
  json.joined_at op.created_at
  json.is_signee op.is_signee
  json.user do
    json.partial! "api/v4/users/user", user: op.user
  end
end
