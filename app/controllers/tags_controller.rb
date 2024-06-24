# frozen_string_literal: true

class TagsController < ApplicationController
  include SetEvent

  before_action :set_event

  def create
    authorize @event, policy_class: TagPolicy

    tag = @event.tags.create_with(label: params[:label].strip, color: params[:color])

    if params[:hcb_code_id]
      hcb_code = HcbCode.find(params[:hcb_code_id])
      authorize hcb_code, :toggle_tag?

      suppress(ActiveRecord::RecordNotUnique) do
        hcb_code.tags << tag
      end
    end

    redirect_back fallback_location: @event
  end

  def destroy
    tag = Tag.find(params[:id])

    authorize tag

    tag.destroy!

    respond_to do |format|
      format.turbo_stream do
        streams = [turbo_stream.remove_all("[data-tag='#{tag.id}']")]
        streams << turbo_stream.remove_all(".tags__divider") if @event.tags.none?
        render turbo_stream: streams
      end
      format.any { redirect_back fallback_location: @event }
    end
  end

end
