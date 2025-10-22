# frozen_string_literal: true

class Event
  class ScopedTagsController < ApplicationController
    include SetEvent

    before_action :set_scoped_tag, except: :create
    before_action :set_event, only: :create

    def create
      @scoped_tag = @event.subevent_scoped_tags.build(name: params[:name])

      authorize @scoped_tag

      if @scoped_tag.save
        respond_to do |format|
          format.turbo_stream { render turbo_stream: turbo_stream.append_all(".scoped_tag_results", partial: "events/scoped_tag_option", locals: { scoped_tag: @scoped_tag }) }
          format.any do
            flash[:success] = "Successfully created new sub-organization tag"
            redirect_back fallback_location: event_sub_organizations_path(@event)
          end
        end
      else
        flash[:error] = "Failed to create new sub-organization tag"
        redirect_to event_sub_organizations_path(@event)
      end
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
