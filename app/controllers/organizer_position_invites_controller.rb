# frozen_string_literal: true

class OrganizerPositionInvitesController < ApplicationController
  include SetEvent
  include ChangePositionRole

  before_action :set_opi, except: [:new, :create]
  before_action :set_event, only: [:new, :create]
  before_action :hide_footer, only: :show

  skip_before_action :signed_in_user, only: [:show]

  def new
    service = OrganizerPositionInviteService::Create.new(event: @event)

    @invite = service.model
    authorize @invite
  end

  def create
    user_email = invite_params[:email]
    role = invite_params[:role]
    is_signee = invite_params[:is_signee] || false

    enable_spending_controls = (invite_params[:enable_controls] == "true") && (role != "manager")
    initial_control_allowance_amount = invite_params[:initial_control_allowance_amount]

    service = OrganizerPositionInviteService::Create.new(event: @event, sender: current_user, user_email:, is_signee:, role:, enable_spending_controls:, initial_control_allowance_amount:)

    @invite = service.model

    authorize @invite

    if service.run
      if @invite.is_signee
        @invite.send_contract(cosigner_email: invite_params[:cosigner_email].presence, include_videos: invite_params[:include_videos])
      end
      flash[:success] = "Invite successfully sent to #{user_email}"
      redirect_to event_team_path @invite.event
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    # If the user's not signed in, redirect them to login page
    unless signed_in?
      skip_authorization
      return redirect_to auth_users_path(return_to: organizer_position_invite_path(@invite)), flash: { info: "Please sign in to accept this invitation." }
    end

    authorize @invite
    @organizers = @invite.event.organizer_positions.includes(:user)
    if @invite.cancelled?
      flash[:error] = "This invitation has been canceled."
      redirect_to root_path
    elsif @invite.accepted?
      redirect_to @invite.event, flash: { success: "You’ve already joined this team!" }
    elsif @invite.rejected?
      redirect_to root_path, flash: { error: "You’ve already rejected this invitation." }
    end
  rescue Pundit::NotAuthorizedError
    if @invite.user != current_user
      flash[:error] = "This invitation was sent to #{@invite.user.redacted_email}, but you are currently logged in as #{current_user.email }."
      redirect_to root_path and return
    end

    raise
  end

  def accept
    authorize @invite

    if @invite.accept
      redirect_to @invite.event
    else
      flash[:error] = @invite.pending_signature? ? "Before accepting the invite, the associated contract needs to be signed by all parties." : "Failed to accept"
      redirect_to @invite
    end
  end

  def reject
    authorize @invite

    if @invite.reject
      flash[:success] = "You’ve rejected your invitation."
      redirect_to root_path
    else
      flash[:error] = "Failed to reject the invitation."
      redirect_to @invite
    end
  end

  def cancel
    authorize @invite

    if @invite.cancel
      flash[:success] = "#{@invite.user.email}\'s invitation has been canceled."
      redirect_to event_team_path(@invite.event)
    else
      flash[:error] = "Failed to cancel the invitation."
      redirect_to @invite.event
    end
  end

  def resend
    authorize @invite

    @invite.deliver

    flash[:success] = "Invite successfully resent to #{@invite.user.email}"
    redirect_to event_team_path @invite.event
  end

  def send_contract
    authorize @invite

    @invite.send_contract(cosigner_email: params[:cosigner_email].presence, include_videos: params[:include_videos])

    flash[:success] = "Contract successfully sent"
    redirect_to event_team_path @invite.event
  end

  private

  def set_opi
    @invite = OrganizerPositionInvite.friendly.find(params[:organizer_position_invite_id] || params[:id])
  end

  def invite_params
    permitted_params = [:email, :role, :enable_controls, :initial_control_allowance_amount]

    if admin_signed_in?
      permitted_params.push(:cosigner_email, :include_videos, :is_signee)
    end
    params.require(:organizer_position_invite).permit(permitted_params)
  end

end
