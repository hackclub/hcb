# frozen_string_literal: true

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
