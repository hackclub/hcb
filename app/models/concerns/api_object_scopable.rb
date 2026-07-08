# frozen_string_literal: true

module ApiObjectScopable
  extend ActiveSupport::Concern

  class_methods do
    def api_resource_type(value = nil)
      @api_resource_type = value if value
      @api_resource_type || name.demodulize.underscore.pluralize
    end

    def api_scope_roots_through(association)
      define_method(:api_scope_roots) do
        parent = public_send(association)
        event = parent.respond_to?(:event) ? parent.event : nil
        { "Event" => event&.id, "User" => user_id }.compact
      end
    end
  end

  def api_scope_roots
    {
      "Event" => is_a?(Event) ? id : (event_id if respond_to?(:event_id)),
      "User"  => is_a?(User) ? id : (user_id if respond_to?(:user_id)),
    }.compact
  end
end
