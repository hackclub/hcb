# frozen_string_literal: true

json.followers @followers, partial: "api/v5/users/user", as: :user
