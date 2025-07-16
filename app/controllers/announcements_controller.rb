# frozen_string_literal: true

class AnnouncementsController < ApplicationController
  before_action :set_announcement, except: [:new]
  before_action :set_event, except: [:new, :create]
  before_action :set_event_follow, except: [:new, :create]

  skip_before_action :signed_in_user, only: [:show]

  def new
    @announcement = Announcement.new
    @event = Event.friendly.find(params[:event_id])
    @announcement.event = @event

    authorize @announcement
  end

  def create
    json_content = params[:announcement][:json_content]
    @event = Event.friendly.find(params[:announcement][:event_id])

    @announcement = authorize Announcement.build(announcement_params.merge(author: current_user, event: @event, content: json_content ))

    @announcement.save!

    unless params[:announcement][:draft] == "true"
      @announcement.mark_published!
    end

    flash[:success] = "Announcement successfully #{params[:announcement][:draft] == "true" ? "drafted" : "published"}!"
    confetti! if @announcement.published?
    redirect_to announcement_path(@announcement)
  rescue => e
    flash[:error] = "Something went wrong. #{e.message}"
    Rails.error.report(e)
    authorize @event, :announcement_overview?
    redirect_to event_announcement_overview_path(@event)
  end

  def show
    authorize @announcement
  end

  def edit
    authorize @announcement

    render "announcements/show", locals: { editing: true }
  end

  def update
    authorize @announcement

    json_content = params[:announcement][:json_content]

    @announcement.transaction do
      @announcement.update!(announcement_params.merge(content: json_content, author: current_user))
      @announcement.mark_draft! if @announcement.template_draft?
    end

    if params[:announcement][:autosave] != "true"
      flash[:success] = "Updated announcement"
      redirect_to announcement_path(@announcement)
    end
  end

  def destroy
    authorize @announcement

    @announcement.destroy!

    flash[:success] = "Deleted announcement"

    redirect_to event_announcement_overview_path(@event)
  end

  def publish
    authorize @announcement

    @announcement.mark_published!

    flash[:success] = "Published announcement"

    redirect_to announcement_path(@announcement)
  end

  private

  def set_announcement
    if params[:id].present?
      @announcement = Announcement.find(params[:id])
    end
  end

  def set_event
    @event = @announcement.event
  end

  def set_event_follow
    @event_follow = Event::Follow.where({ user_id: current_user.id, event_id: @event.id }).first if current_user
  end

  def announcement_params
    params.require(:announcement).permit(:title)
  end

end
