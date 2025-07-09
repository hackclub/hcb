# frozen_string_literal: true

class AnnouncementsController < ApplicationController
  before_action :set_announcement, except: [:new]
  before_action :set_event, except: [:new, :create]
  before_action :set_event_follow, except: [:new, :create]

  def new
    @announcement = Announcement.new
    @announcement.event = Event.find(id:)

    authorize @announcement
  end

  def create
    @announcement = authorize Announcement.build(announcement_params.merge(author: current_user, event: Event.friendly.find(params[:announcement][:event_id])))

    @announcement.save!

    unless params[:announcement][:draft] == "true"
      @announcement.publish!
    end

    flash[:success] = "Announcement successfully #{params[:announcement][:draft] == "true" ? "drafted" : "published"}!"
    redirect_to announcement_path(@announcement)

  rescue => e
    puts e.message
    flash[:error] = "Something went wrong. #{e.message}"
    Rails.error.report(e)
    redirect_to event_announcement_overview_path(@announcement.event)
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

    @announcement.update!(announcement_params)

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

    @announcement.publish!

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
    params.require(:announcement).permit(:title, :content)
  end

end
