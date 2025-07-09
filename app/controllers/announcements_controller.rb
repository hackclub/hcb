# frozen_string_literal: true

class AnnouncementsController < ApplicationController
  before_action :set_event
  before_action :set_announcement, except: [:new]
  before_action :set_event_follow

  def new
    @announcement = Announcement.new
    @announcement.event = @event

    authorize @announcement
  end

  def create
    @announcement = @event.announcements.build(params.require(:announcement).permit(:title, :content).merge(author: current_user))

    authorize @announcement

    @announcement.save!

    unless params[:announcement][:draft] == "true"
      @announcement.publish!
    end

    flash[:success] = "Announcement successfully #{params[:announcement][:draft] == "true" ? "drafted" : "published"}!"

  rescue => e
    puts e.message
    flash[:error] = "Something went wrong. #{e.message}"
    Rails.error.report(e)
  ensure
    redirect_to event_announcement_path(@event, @announcement)
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

    @announcement.update!(params.require(:announcement).permit(:title, :content))

    if params[:announcement][:autosave] != "true"
      flash[:success] = "Updated announcement"
      redirect_to event_announcement_path(@event, @announcement)
    end
  end

  def destroy
    authorize @announcement

    @announcement.destroy!

    flash[:success] = "Deleted announcement"

    redirect_to event_announcements_path(@event)
  end

  def publish
    authorize @announcement

    @announcement.publish!

    flash[:success] = "Published announcement"

    redirect_to event_announcement_path(@event, @announcement)
  end

  private

  def set_announcement
    if params[:id].present?
      @announcement = @event.announcements.find(params[:id])
    end
  end

  def set_event
    if params[:event_id].present?
      @event = Event.find_by!(slug: params[:event_id])
    end
  end

  def set_event_follow
    @event_follow = Event::Follow.where({ user_id: current_user.id, event_id: @event.id }).first if current_user
  end

end
