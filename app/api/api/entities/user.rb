# frozen_string_literal: true

module Api
  module Entities
    class User < Base
      include UsersHelper # for `profile_picture_for`

      # Since User is a small object, the full name and photo is included in the
      # minimized version of the object.
      expose :name, as: :full_name
      expose :auditor?, as: :auditor, documentation: { type: "boolean" }
      expose :admin?, as: :admin, documentation: { type: "boolean" }
      expose :photo do |user, options|
        profile_picture_for user
      end

      unexpose :href # Users don't have a `get` endpoint (they aren't a resource in our v3 API)

    end
  end
end
