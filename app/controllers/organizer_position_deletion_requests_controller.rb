# frozen_string_literal: true

class OrganizerPositionDeletionRequestsController < ApplicationController
  include SetEvent
  before_action :set_opdr, only: [:show, :close, :open]

  def index
    authorize OrganizerPositionDeletionRequest
    @opdrs = OrganizerPositionDeletionRequest
             .order(Arel.sql("closed_at IS NULL DESC")) # Place open requests at the top
             .order(created_at: :desc)
             .includes(:submitted_by, organizer_position: :event)
             .page(params[:page])
  end

  def show
    authorize @opdr

    @commentable = @opdr
    @comments = @commentable.comments
  end

  def new
    if params[:event_id].nil?
      @op = OrganizerPosition.find(params[:organizer_position_id])
      authorize @op.organizer_position_deletion_requests.build
      return redirect_to new_event_organizer_position_remove_path(event_id: @op.event.slug, organizer_position_id: @op.user.slug)
    else
      set_event
    end

    begin
      @user = User.friendly.find(params[:organizer_position_id])
      @op = OrganizerPosition.find_by!(event: @event, user: @user)
    rescue ActiveRecord::RecordNotFound
      @op = OrganizerPosition.find_by!(event: @event, id: params[:organizer_position_id])
    end

    @event = @op.event
    @opdr = OrganizerPositionDeletionRequest.new(organizer_position: @op)
    authorize @opdr

    @target = @op.user
  end

  def create
    attributes = filtered_params
    attributes[:submitted_by] = current_user
    @opdr = OrganizerPositionDeletionRequest.new(attributes)
    @op = @opdr.organizer_position
    @target = @op.user
    @event = @op.event

    authorize @opdr

    if @opdr.save
      flash[:success] = "Removal request submitted. We’ll be in touch shortly."
      redirect_to event_team_path(@event)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def close
    authorize OrganizerPositionDeletionRequest
    @opdr.close current_user
    flash[:success] = "Removal request closed."
    redirect_to organizer_position_deletion_requests_path
  end

  def open
    authorize OrganizerPositionDeletionRequest
    @opdr.open
    flash[:success] = "Removal request re-opened."
    redirect_to @opdr
  end

  private

  def set_opdr
    id = params[:organizer_position_deletion_request_id] || params[:id]
    @opdr = OrganizerPositionDeletionRequest.find(id)
    @event = @opdr.organizer_position.event
  end

  def filtered_params
    params.require(:organizer_position_deletion_request).permit(:organizer_position_id, :reason, :subject_emails_should_be_forwarded)
  end

end
