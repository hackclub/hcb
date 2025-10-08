# frozen_string_literal: true

class OrganizerPositionInvite
  class LinksController < ApplicationController
    include SetEvent
    before_action :set_event, only: [:index, :new, :create]
    before_action :set_link, except: [:index, :new, :create]

    def index
      authorize @event.organizer_position_invite_links.build

      @invite_links = @event.organizer_position_invite_links.active
    end

    def show
      authorize @link

      redirect_to event_path(@link.event) if @link.event.users.include?(current_user)
      flash[:success] = "You already have access to #{@link.event.name}!"

      @organizers = @link.event.organizer_positions
    end

    def new
      authorize @event.organizer_position_invite_links.build
    end

    def create
      expires_in = (params[:expires_on].to_datetime - DateTime.now).to_f * 24 * 60 * 60 if params[:expires_on].present?
      @link = @event.organizer_position_invite_links.build({creator: current_user, expires_in:}.compact)

      authorize @link

      if @link.save
        redirect_to event_team_path(event_id: @event.id), flash: { success: "Invite link successfully created." }
      else
        render :new, status: :unprocessable_entity
      end
    end

    def deactivate
      authorize @link

      if @link.deactivate(user: current_user)
        redirect_to event_team_path(event_id: @link.event.id), flash: { success: "Invite link successfully deactivated." }
      else
        redirect_to event_team_path(event_id: @link.event.id), flash: { error: "Failed to deactivate invite link." }
      end
    end

    private

    def set_link
      @link = OrganizerPositionInvite::Link.find_by_hashid(params[:id])
    end

  end

end
