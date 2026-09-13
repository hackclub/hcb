# frozen_string_literal: true

module Api
  module V5
    class OrganizerPositionInvitesController < ApplicationController
      include Api::V5::TransferCreation
      include Api::V5::ScopedResource

      scoped_resource OrganizerPositionInvite, organization_scope: :event,
                                               preload: [:event, :user, :sender]

      require_oauth2_scope "invitations:read", :index, :show

      def create
        event = find_organization!(params[:organization_id])
        authorize event, :can_invite_user?

        service = OrganizerPositionInviteService::Create.new(
          event:,
          sender: current_user,
          user_email: params[:email],
          is_signee: false,
          role: params[:role],
          enable_spending_controls: params[:enable_spending_controls],
          initial_control_allowance_amount: params[:initial_control_allowance_amount]
        )

        @record = service.model
        authorize @record
        service.run!

        render :show, status: :created
      end

      require_oauth2_scope "invitations:write", :create

      # accept and reject act on an invitation addressed to the caller, so the
      # record's own ownership is the authorization — there is no organization
      # role involved. `authorize` still runs, against that.
      def accept
        @record = authorize find_invitation!, :accept?
        raise ActiveRecord::RecordInvalid.new(@record) unless @record.accept(show_onboarding: false)

        render :show
      end

      require_oauth2_scope "invitations:write", :accept

      def reject
        @record = authorize find_invitation!, :reject?
        raise ActiveRecord::RecordInvalid.new(@record) unless @record.reject

        render :show
      end

      require_oauth2_scope "invitations:write", :reject

      def destroy
        invitation = authorize find_invitation!
        raise ActiveRecord::RecordInvalid.new(invitation) unless invitation.cancel

        render json: { message: "Invitation successfully deleted" }, status: :ok
      end

      require_oauth2_scope "invitations:write", :destroy

      private

      def find_invitation!
        OrganizerPositionInvite.find_by_public_id!(params[:id])
      end
    end
  end
end
