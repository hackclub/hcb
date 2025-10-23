# frozen_string_literal: true

class Event
  class ScopedTagsController < ApplicationController
    include SetEvent

    before_action :set_scoped_tag, except: :create
    before_action :set_event

    def create
      @scoped_tag = @event.subevent_scoped_tags.build(name: params[:name])

      authorize @scoped_tag

      if @scoped_tag.save
        if params[:subevent_id]
          subevent = Event.find(params[:subevent_id])

          if @scoped_tag.parent_event.subevents.include?(subevent)
            subevent.scoped_tags << @scoped_tag
          end
        end

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
        format.turbo_stream do
          streams = [turbo_stream.remove_all("[data-scoped-tag='#{@scoped_tag.id}']")]
          streams << turbo_stream.remove_all(".scoped-tags__divider") if @event.subevent_scoped_tags.none?
          render turbo_stream: streams
        end
        format.any { redirect_back fallback_location: event_sub_organizations_path(@scoped_tag.parent_event) }
      end
    end

    def toggle_tag
      authorize @scoped_tag

      unless @scoped_tag.parent_event.subevents.include?(@event)
        flash[:error] = "Cannot add tag of a different parent organization to this organization"
        return redirect_to event_sub_organizations_path(@scoped_tag.parent_event)
      end

      if @event.scoped_tags.exists?(@scoped_tag.id)
        removed = true
        @event.scoped_tags.destroy(@scoped_tag)
      else
        @event.scoped_tags << @scoped_tag
      end

      respond_to do |format|
        format.turbo_stream do
          if removed
            render partial: "events/scoped_tags/destroy", locals: { scoped_tag: @scoped_tag, subevent: @event }
          else
            render partial: "events/scoped_tags/create", locals: { scoped_tag: @scoped_tag, subevent: @event }
          end
        end
        format.any { redirect_back fallback_location: event_sub_organizations_path(@scoped_tag.parent_event) }
      end
    end

    private

    def set_scoped_tag
      @scoped_tag = Event::ScopedTag.find(params[:id])
    end

  end

end
