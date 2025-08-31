# frozen_string_literal: true

class AnnouncementsController < ApplicationController
  before_action :set_announcement, except: [:new]
  before_action :set_event, except: [:new, :create]
  before_action :set_event_follow, except: [:new, :create]

  skip_before_action :signed_in_user, only: [:show]

  def new
    @event = Event.friendly.find(params[:event_id])
    @announcement = Announcement.build(content: {}, title: "", author: current_user, event: @event)

    authorize @announcement

    @show_announcement_explanation = Announcement.where(author: current_user).where.not(published_at: nil).empty?

    @announcement.save!
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

    @announcement.content = ProsemirrorService::Renderer.set_html(@announcement.content, source_event: @announcement.event)

    render "announcements/show", locals: { editing: true }
  end

  def update
    authorize @announcement

    content_hash = JSON.parse(params[:announcement][:json_content])
    @announcement.transaction do
      @announcement.update!(announcement_params.merge({ content: ProsemirrorService::Renderer.set_html(content_hash), author: @announcement.author == User.system_user ? current_user : nil }.compact))
      @announcement.mark_draft! if @announcement.template_draft?

      if params[:announcement][:draft] == "false" && !@announcement.published?
        @announcement.mark_published!
      end
    end

    block_ids = ProsemirrorService::Renderer.block_ids(content_hash)
    Announcement::Block.where(announcement: @announcement).find_each do |block|
      unless block_ids.include? block.id
        block.destroy
      end
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

    if @announcement.mark_published!
      flash[:success] = "Published announcement"
    else
      flash[:error] = @announcement.errors.full_messages.to_sentence
    end

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
