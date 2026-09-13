# frozen_string_literal: true

module Api
  module V5
    class CardGrantsController < ApplicationController
      include Api::V5::ScopedResource

      scoped_resource CardGrant, organization_scope: :event, preload: [:event, :user, :stripe_card]

      require_oauth2_scope "card_grants:read", :index, :show

      def create
        event = find_organization!(params[:organization_id])
        attrs = permitted_attributes(CardGrant.new(event:))

        @record = event.card_grants.build(attrs.merge(sent_by: sender))
        authorize @record

        @record.save!

        render :show, status: :created
      rescue ActiveRecord::RecordInvalid => e
        # CardGrant#save! runs DisbursementService::Create underneath, so a
        # failure here can be the grant's own validations or a downstream
        # money-movement error. Only the former is the caller's to fix; the rest
        # re-raises to the generic handler rather than being reported as a bad
        # request.
        raise e unless e.record.is_a?(CardGrant)

        render json: { error: "invalid_operation", messages: @record.errors.full_messages },
               status: :unprocessable_content
      rescue DisbursementService::Create::UserError => e
        render json: { error: "invalid_operation", messages: [e.message] }, status: :unprocessable_content
      end

      require_oauth2_scope "card_grants:write", :create

      def update
        @record = authorize find_grant!
        @record.update!(permitted_attributes(@record))

        render :show
      end

      require_oauth2_scope "card_grants:write", :update

      def topup
        @record = authorize find_grant!
        @record.topup!(amount_cents: params[:amount_cents], topped_up_by: current_user)

        render :show
      end

      require_oauth2_scope "card_grants:write", :topup

      def withdraw
        @record = authorize find_grant!
        @record.withdraw!(amount_cents: params[:amount_cents], withdrawn_by: current_user)

        render :show
      end

      require_oauth2_scope "card_grants:write", :withdraw

      def cancel
        @record = authorize find_grant!
        @record.cancel!(current_user)

        render :show
      end

      require_oauth2_scope "card_grants:write", :cancel

      def activate
        @record = authorize find_grant!
        @record.create_stripe_card(request.remote_ip)

        render :show
      end

      require_oauth2_scope "card_grants:write", :activate

      private

      def find_grant!
        CardGrant.find_by_public_id!(params[:id])
      end

      # An admin may issue a grant on someone else's behalf; everyone else
      # sends as themselves.
      def sender
        return current_user unless can_admin?(:write) && params[:sent_by_email].present?

        User.find_by(email: params[:sent_by_email]) ||
          raise(ActiveRecord::RecordNotFound.new(nil, "User"))
      end
    end
  end
end
