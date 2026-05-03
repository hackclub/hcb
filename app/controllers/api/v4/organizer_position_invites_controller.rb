# frozen_string_literal: true

module Api
  module V4
    class OrganizerPositionInvitesController < ApplicationController
      include SetEvent

      before_action :set_api_event, only: [:create]
      before_action :set_invitation, only: [:show, :destroy, :accept, :reject]

      def index
        if params[:organization_id].present?
          set_api_event
          authorize @event, :index_in_v4?
          @invitations = @event.organizer_position_invites.pending.order(:id)
        else
          skip_authorization
          @invitations = current_user.organizer_position_invites.pending.order(:id)
        end

        @total_count = @invitations.count
        @invitations = paginate_cursor(@invitations)
      end

      def show
        authorize @invitation
      end

      def create
        authorize @event, :can_invite_user?

        service = OrganizerPositionInviteService::Create.new(event: @event, sender: current_user, user_email: params[:email], is_signee: false, role: params[:role], enable_spending_controls: params[:enable_spending_controls], initial_control_allowance_amount: params[:initial_control_allowance_amount])

        @invitation = service.model
        authorize @invitation

        service.run!
        render :show, status: :created
      end

      def accept
        authorize @invitation

        unless @invitation.accept(show_onboarding: false)
          raise ActiveRecord::RecordInvalid.new(@invitation)
        end

        render :show
      end

      def reject
        authorize @invitation

        unless @invitation.reject
          raise ActiveRecord::RecordInvalid.new(@invitation)
        end

        render :show
      end

      def destroy
        authorize @invitation

        unless @invitation.cancel
          raise ActiveRecord::RecordInvalid.new(@invitation)
        end

        render json: { message: "Invitation successfully deleted" }, status: :ok
      end

      private

      def set_invitation
        @invitation = OrganizerPositionInvite.find_by_public_id!(params[:id])
        raise ActiveRecord::RecordNotFound if @invitation.cancelled? || @invitation.rejected?
      end

    end
  end
end
