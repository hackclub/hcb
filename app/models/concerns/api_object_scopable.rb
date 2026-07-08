# frozen_string_literal: true

# Gives every model a default answer to the two questions the v4 API's
# object-scoping layer needs (see ApiToken::ResourceGrant):
#   - api_resource_type: which scope-string resource name this record counts
#     as (defaults to the pluralized class name; override when a scope name
#     spans multiple classes, e.g. "transfers" covers AchTransfer/Check/...).
#   - #api_scope_roots: which User/Event this record belongs to, for grants
#     that narrow access to "everything under this org/user" rather than one
#     specific record. Defaults to this record's own event_id/user_id columns
#     when present; override on models where the owning event/user is only
#     reachable indirectly (e.g. through a polymorphic association).
module ApiObjectScopable
  extend ActiveSupport::Concern

  class_methods do
    def api_resource_type(value = nil)
      @api_resource_type = value if value
      @api_resource_type || name.demodulize.underscore.pluralize
    end
  end

  def api_scope_roots
    {
      "Event" => is_a?(Event) ? id : (event_id if respond_to?(:event_id)),
      "User" => is_a?(User) ? id : (user_id if respond_to?(:user_id)),
    }.compact
  end
end
