# frozen_string_literal: true

json.id user.public_id
json.name user.name
json.email user.email
json.avatar profile_picture_for(user, params[:avatar_size].presence&.to_i || 24)
json.admin user.admin?
json.auditor user.auditor?
