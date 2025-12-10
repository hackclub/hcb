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

      unless @link.active?
        flash[:error] = "This invite link has expired."
        redirect_to root_path and return
      end


      if @link.event.users.include?(current_user)
        flash[:success] = "You already have access to #{@link.event.name}!"
        redirect_to event_path(@link.event) and return
      end

      if (pending_invite = @link.event.organizer_position_invites.pending.find_by(user: current_user))
        flash[:success] = { text: "You already have an invitation to #{@link.event.name}!", link: organizer_position_invite_path(pending_invite), link_text: "Accept invite" }
        redirect_to root_path and return
      end

      if @link.event.organizer_position_invite_requests.pending.where(requester: current_user).any?
        flash[:success] = "You already requested to join! Ask a manager of #{@link.event.name} to accept your request."
        redirect_to root_path and return
      end

      @organizers = @link.event.organizer_positions
    end

    def new
      authorize @event.organizer_position_invite_links.build
    end

    def create
      expires_in = ActiveSupport::Duration.build(params[:expires_on].to_time - Time.now).seconds.to_i if params[:expires_on].present?
      @link = @event.organizer_position_invite_links.build({ creator: current_user, expires_in: }.compact)

      authorize @link

      if @link.save
        @invite_links = @event.organizer_position_invite_links.active

        respond_to do |format|
          format.html { redirect_to event_team_path(event: @event), flash: { success: "Invite link successfully created." } }
          format.turbo_stream {
            render turbo_stream: turbo_stream.replace("invite_links_section", partial: "events/invite_links_section", locals: { event: @event, invite_links: @invite_links })
          }
        end
      else
        render :new, status: :unprocessable_entity
      end
    end

    def deactivate
      authorize @link

      @event = @link.event
      @invite_links = @event.organizer_position_invite_links.active
      if @link.deactivate(user: current_user)

        respond_to do |format|
          format.html { redirect_to event_team_path(event: @event), flash: { success: "Invite link successfully deactivated." } }
          format.turbo_stream {
            render turbo_stream: turbo_stream.replace("invite_links_section", partial: "events/invite_links_section", locals: { event: @event, invite_links: @invite_links })
          }
        end
      else

        respond_to do |format|
          format.html { redirect_to event_team_path(event: @event), flash: { error: "Failed to deactivate invite link." } }
          format.turbo_stream {
            flash.now[:error] = "Failed to deactivate invite link."
            render turbo_stream: turbo_stream.replace("invite_links_section", partial: "events/invite_links_section", locals: { event: @event, invite_links: @invite_links }), status: :unprocessable_entity
          }
        end
      end
    end

    private

    def set_link
      @link = OrganizerPositionInvite::Link.find_by_hashid(params[:id])
    end

  end

end
