# frozen_string_literal: true

class Event
  class FollowsController < ApplicationController
    include SetEvent
    skip_before_action :signed_in_user, only: :create
    before_action :set_event, only: :create

    def create
      unless signed_in?
        skip_authorization
        return redirect_to auth_users_path(return_to: event_url(@event), require_reload: true)
      end

      attrs = {
        user_id: current_user.id,
        event: @event
      }
      follow = Event::Follow.new(attrs)
      authorize follow
      follow.save!
      redirect_to event_announcements_path(@event)
    end

    def destroy
      @event_follow = Event::Follow.find(params[:id])
      authorize @event_follow
      slug = @event_follow.event.slug
      @event_follow.destroy!
      redirect_to event_path(slug)
    end

  end

end
