# frozen_string_literal: true

module Api
  module V4
    class InvitationsController < ApplicationController
      include SetEvent

      skip_after_action :verify_authorized, only: [:index]
      before_action :set_invitation, except: [:index]
      before_action :set_api_event, only: [:create]

      def index
        @invitations = current_user.organizer_position_invites.pending
      end

      def show
        authorize @invitation
      end

      def create
        authorize @event

        unless policy(@event).can_invite_user?
          return render json: { error: "You are not authorized to invite users" }, status: :forbidden
        end

        if @event.organizer_positions.exists?(user: User.find_by(email: params[:email]))
          return render json: { error: "User is already an organizer" }, status: :unprocessable_entity
        end

        if @event.organizer_position_invites.pending.exists?(email: params[:email])
          return render json: { error: "User already has a pending invitation" }, status: :unprocessable_entity
        end

        service = OrganizerPositionInviteService::Create.new(event: @event, sender: current_user, user_email: params[:email], role: params[:role], enable_spending_controls: params[:enable_spending_controls], initial_control_allowance_amount: params[:initial_control_allowance_amount])

        @invitation = service.model

        authorize @invitation

        if service.run
          render :show, status: :created
        else
          render json: { error: "Failed to create invitation" }, status: :unprocessable_entity
        end
      end

      def accept
        unless @invitation.accept(show_onboarding: false)
          raise ActiveRecord::RecordInvalid.new(@invitation)
        end

        render :show
      end

      def reject
        unless @invitation.reject
          raise ActiveRecord::RecordInvalid.new(@invitation)
        end

        render :show
      end

      private

      def set_invitation
        @invitation = authorize OrganizerPositionInvite.find_by_public_id(params[:id]) || OrganizerPositionInvite.friendly.find(params[:id])

        if @invitation.cancelled? || @invitation.rejected? || @invitation.user != current_user
          raise ActiveRecord::RecordNotFound
        end
      end

    end
  end
end
