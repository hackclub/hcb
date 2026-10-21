# frozen_string_literal: true

class TagsController < ApplicationController
  include SetEvent

  before_action :set_event

  def create
    authorize @event, policy_class: TagPolicy

    label = params[:label].strip
    tag = Tag.where(label: label, event: @event).first_or_initialize(color: params[:color], emoji: params[:emoji])
    tag.save unless tag.persisted?

    if !tag.persisted? && tag.errors.of_kind?(:label, :taken)
      # Another request created this same tag concurrently (e.g. a double
      # submit) between our lookup above and our attempted create. Use the
      # tag it created instead of carrying forward an invalid record.
      tag = Tag.find_by(label: label, event: @event) || tag
    end

    if params[:hcb_code_id]
      hcb_code = HcbCode.find(params[:hcb_code_id])
      authorize hcb_code, :toggle_tag?

      # `toggle_tag?` only asks whether the user is a member of *some* event on
      # this HCB code, so it would let a member of two organizations attach one
      # organization's tag to the other's transaction. `HcbCodes#toggle_tag`
      # guards the same gap.
      raise Pundit::NotAuthorizedError unless hcb_code.events.include?(@event)

      suppress(ActiveRecord::RecordNotUnique) do
        hcb_code.tags << tag
      end
    end

    redirect_back fallback_location: @event
  end

  def update
    tag = Tag.find(params[:id])

    authorize tag

    tag.update(label: params[:label].strip, color: params[:color], emoji: params[:emoji])

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
