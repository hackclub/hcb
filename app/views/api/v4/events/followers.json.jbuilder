# frozen_string_literal: true

json.followers @followers, partial: "api/v4/users/user", as: :user
