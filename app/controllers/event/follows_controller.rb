class Event
  class FollowsController < ApplicationController
    include SetEvent
    before_action :set_event

    def create
      attrs = {
        user_id: current_user.id,
        event: @event
      }
      follow = Event::Follow.new(attrs)
      if authorize follow
        Event::Follow.create(attrs)
        redirect_to event_announcements_path(@event)
      else
        flash[:error] = "You aren't allowed to follow this event."
      end
    end

    def destroy
      @event_follow = Event::Follow.find(params[:id])
      if authorize @event_follow
        @event_follow.destroy
        redirect_to event_path(@event)
      else
        flash[:error] = "Failed to unfollow this event."
      end
    end

  end

end
