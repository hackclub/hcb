# frozen_string_literal: true

class User
  class PermissionsOverview
    Node = Struct.new(:event, :role, :child_nodes, keyword_init: true)

    def initialize(user:)
      @user = user
    end

    def role_by_event_id
      @role_by_event_id ||= compute_role_by_event_id
    end

    def event_graph
      events_by_id
        .values
        .select { |event| event.parent_id.nil? }
        .map { |event| event_node(event) }
    end

    private

    attr_reader(:user)

    def compute_role_by_event_id
      events_by_id.to_h do |event_id, _event|
        ancestor_roles = ancestor_event_ids(event_id).filter_map do |event_id|
          organizer_positions_by_event_id[event_id]&.role
        end

        # If the user is a manager of this or any ancestor events they are
        # considered a manager
        if ancestor_roles.include?("manager")
          next [event_id, "manager"]
        end

        # If a user is a member of this event, they are considered a member
        # (we do not take ancestor roles into account here)
        op = organizer_positions_by_event_id[event_id]
        if op&.role == "member"
          next [event_id, "member"]
        end

        # If a user is a reader of this or any ancestor events they are
        # considered a reader
        if ancestor_roles.present?
          next [event_id, "reader"]
        end

        [event_id, nil]
      end
    end

    def organizer_positions_by_event_id
      @organizer_positions_by_event_id ||=
        user
        .organizer_positions
        .strict_loading
        .index_by(&:event_id)
    end

    def events_by_id
      @events_by_id ||= begin
        active_events = Event.unscoped.where(Event.paranoid_default_scope)

        recursive_query = ->(non_recursive_term, recursive_term) {
          Event
            .unscoped
            .with_recursive(event_graph: [non_recursive_term, recursive_term])
            .select("event_graph.*")
            .from("event_graph")
            .strict_loading
        }

        descendants = recursive_query.call(
          active_events.where(parent_id: organizer_positions_by_event_id.keys),
          active_events.joins("JOIN event_graph ON events.parent_id = event_graph.id"),
        )

        ancestors = recursive_query.call(
          active_events.where(id: organizer_positions_by_event_id.keys),
          active_events.joins("JOIN event_graph ON events.id = event_graph.parent_id")
        )

        (ancestors + descendants).index_by(&:id)
      end
    end

    def events_by_parent_id
      @events_by_parent_id ||= events_by_id.values.group_by(&:parent_id)
    end

    def ancestor_event_ids(event_id)
      Enumerator.new do |yielder|
        current_event_id = event_id

        until current_event_id.nil?
          yielder << current_event_id

          current_event = events_by_id.fetch(current_event_id)
          current_event_id = current_event.parent_id
        end
      end
    end

    def event_node(event)
      role = role_by_event_id.fetch(event.id)

      child_nodes =
        events_by_parent_id
        .fetch(event.id, [])
        .map { |event| event_node(event) }

      Node.new(event:, role:, child_nodes:)
    end

  end

end
