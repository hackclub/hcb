# frozen_string_literal: true

class Event
  class ScopedTagsController < ApplicationController
    before_action :set_scoped_tag, except: :create

    def create
      @event = Event.find(params[:event_id])
      authorize @event
    end

    def destroy
      authorize @scoped_tag

      @scoped_tag.destroy!

      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.remove_all("[data-scoped-tag='#{@scoped_tag.id}']") }
        format.any { redirect_back fallback_location: event_sub_organizations_path(@scoped_tag.parent_event) }
      end
    end

    private

    def set_scoped_tag
      @scoped_tag = Event::ScopedTag.find(params[:id])
    end

  end

end
