# frozen_string_literal: true

module Api
  module V5
    module ApplicationHelper
      include UsersHelper # for `profile_picture_for`
      include ::ApplicationHelper

      attr_reader :current_user, :current_token

      # Renders the standard object envelope and yields an `Api::FieldSet`
      # scoped to what this user may see on this record.
      #
      # Serializers write fields through the yielded emitter rather than
      # through `json`, so attribute-level authorization is deny-by-default:
      # anything the record's policy doesn't list in `visible_attributes` is
      # never emitted. `id` and `object` are always present — a caller that
      # reached this object is allowed to know it exists, and v3's "minimized"
      # shape is exactly these two keys.
      def object_shape(json, record, object_name: nil, created_at: true)
        json.id record.public_id
        json.object object_name || record.model_name.singular

        yield Api::FieldSet.new(json, policy(record).visible_attributes)

        json.created_at record.created_at if created_at
      end

    end
  end
end
