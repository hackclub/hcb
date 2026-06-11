# frozen_string_literal: true

# Adds a `set_event` method to a controller.
# Why are we not using FriendlyId's built-in history module? See https://github.com/hackclub/hcb/pull/2714#pullrequestreview-1022038333
module SetEvent
  extend ActiveSupport::Concern

  included do
    private

    def set_event
      id = params[:event_name] || params[:event_id] || params[:id]
      id ||= params[:event] if params[:event].is_a?(String) # sometimes params[:event] is a hash with nested attributes

      if request.get? && id == "org"
        unless signed_in?
          redirect_to auth_users_path(return_to: request.original_url, require_reload: true)
          return
        end

        nav_items = EventsHelper::NAV_ITEMS.flat_map do |item|
          item[:dropdown_items]&.map { |di| di.merge(name: "#{item[:dropdown]} (#{di[:name]})", icon: item[:icon]) } || [item]
        end.select { |item| item[:adminTool].nil? && item[:path_proc].present? }

        @nav_item = nav_items.find do |item|
          item_path = instance_exec("org", &item[:path_proc])

          helpers.current_page?(item_path)
        end

        if @nav_item.nil?
          raise ActionController::RoutingError.new("Not Found")
        end

        if current_user.events.one?
          redirect_to instance_exec(current_user.events.first.slug, &@nav_item[:path_proc])
          return
        end

        @available_events = []
        @unavailable_events = []

        current_user.events.not_hidden.each do |e|
          if instance_exec(e, &@nav_item[:available_proc])
            @available_events << e
          else
            @unavailable_events << e
          end
        end

        render "events/placeholder"
        return
      end

      @event = auditor_signed_in? ? Event.friendly.find(id) : Event.friendly.find_by_friendly_id(id)

      @organizer_position = @event.organizer_positions.find_by(user: current_user) if signed_in?
      @first_time = params[:first_time] || @organizer_position&.first_time?

    rescue ActiveRecord::RecordNotFound
      # Attempt to find this slug in the history
      @event = FriendlyId::Slug.order(id: :desc).find_by(slug: id, sluggable_type: "Event")&.sluggable

      unless @event || auditor_signed_in?
        return redirect_to root_path, flash: { error: "We couldn’t find that organization!" }
      end

      unless @event
        return redirect_to events_admin_index_path(q: id), flash: { error: "We couldn’t find that organization!" }
      end

      # Redirect to the new slug
      if id == params[:event_name]
        params[:event_name] = @event.slug
      elsif id == params[:event_id]
        params[:event_id] = @event.slug
      elsif id == params[:id]
        params[:id] = @event.slug
      end

      redirect_to params.to_unsafe_h
    end

    def set_api_event
      if params[:event_id]
        @event = Event.find_by_public_id(params[:event_id]) || Event.friendly.find(params[:event_id])
      else
        @event = Event.find_by_public_id(params[:organization_id]) || Event.friendly.find(params[:organization_id])
      end
    end

  end

end
