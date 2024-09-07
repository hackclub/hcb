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
      @event = admin_signed_in? ? Event.friendly.find(id) : Event.friendly.find_by_friendly_id(id)

      @organizer_position = @event.organizer_positions.find_by(user: current_user) if signed_in?
      @first_time = params[:first_time] || @organizer_position&.first_time?

    rescue ActiveRecord::RecordNotFound
      # Attempt to find this slug in the history
      @event = FriendlyId::Slug.order(id: :desc).find_by(slug: id, sluggable_type: "Event")&.sluggable

      if !@event
        return redirect_to root_path, flash: { error: "We couldn’t find that organization!" }
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

  end

end
